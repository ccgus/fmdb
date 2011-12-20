//
//  FMDatabasePool.m
//  fmdb
//
//  Created by August Mueller on 6/22/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import "FMDatabaseQueue.h"
#import "FMDatabase.h"

@implementation FMDatabaseQueue

@synthesize path = _path;

+ (id)databaseQueueWithPath:(NSString*)aPath {
    return [[[self alloc] initWithPath:aPath] autorelease];
}

- (id)initWithPath:(NSString*)aPath {
	
    self = [super init];
    
	if (self != nil) {
        
        _db = [[FMDatabase databaseWithPath:aPath] retain];
        
        if (![_db open]) {
            NSLog(@"Could not create database queue for path %@", aPath);
            [self release];
            return 0x00;
        }
        
        _path = [aPath retain];
        
        _queue = dispatch_queue_create([[NSString stringWithFormat:@"fmdb.%@", self] UTF8String], NULL);
	}
    
	return self;
}

- (void)dealloc {
    
    [_db release];
    [_path release];
    
    if (_queue) {
        dispatch_release(_queue);
        _queue = 0x00;
    }
    
    [super dealloc];
}

- (void)close {
    dispatch_sync(_queue, ^() { 
        [_db close];
        [_db release];
        _db = 0x00;
    });
}

- (FMDatabase*)database {
    if (!_db) {
        _db = [[FMDatabase databaseWithPath:_path] retain];
        if (![_db open]) {
            NSLog(@"FMDatabaseQueue could not reopen database for path %@", _path);
            [_db release];
            _db  = 0x00;
            return 0x00;
        }
    }
    
    return _db;
}

- (void)inDatabase:(void (^)(FMDatabase *db))block {
    
    dispatch_sync(_queue, ^() {
        
        FMDatabase *db = [self database];
        block(db);
        
        if ([db hasOpenResultSets]) {
            NSLog(@"Warning: there is at least one open result set around after performing [FMDatabaseQueue inDatabase:]");
        }
        
    });
}

- (void)beginTransaction:(BOOL)useDeferred withBlock:(void (^)(FMDatabase *db, BOOL *rollback))block {
    
    dispatch_sync(_queue, ^() { 
        
        BOOL shouldRollback = NO;
        
        if (useDeferred) {
            [[self database] beginDeferredTransaction];
        }
        else {
            [[self database] beginTransaction];
        }
        
        block([self database], &shouldRollback);
        
        if (shouldRollback) {
            [[self database] rollback];
        }
        else {
            [[self database] commit];
        }
    
    });
}

- (void)inDeferredTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block {
    [self beginTransaction:YES withBlock:block];
}

- (void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block {
    [self beginTransaction:NO withBlock:block];
}

#if SQLITE_VERSION_NUMBER >= 3007000
- (NSError*)inSavePoint:(void (^)(FMDatabase *db, BOOL *rollback))block {
    
    static unsigned long savePointIdx = 0;
    __block NSError *err = 0x00;
    
    dispatch_sync(_queue, ^() { 
        
        NSString *name = [NSString stringWithFormat:@"savePoint%ld", savePointIdx++];
        
        BOOL shouldRollback = NO;
        
        if ([[self database] startSavePointWithName:name error:&err]) {
            
            block([self database], &shouldRollback);
            
            if (shouldRollback) {
                [[self database] rollbackToSavePointWithName:name error:&err];
            }
            else {
                [[self database] releaseSavePointWithName:name error:&err];
            }
            
        }
    });
    
    return err;
}
#endif

@end
