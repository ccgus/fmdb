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
    [_db close];
    [_db release];
    _db = 0x00;
}

- (FMDatabase*)db {
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
    dispatch_sync(_queue, ^() { block([self db]); });
}

- (void)beginTransaction:(BOOL)useDeferred withBlock:(void (^)(FMDatabase *db, BOOL *rollback))block {
    
    dispatch_sync(_queue, ^() { 
        
        BOOL shouldRollback = NO;
        
        if (useDeferred) {
            [[self db] beginDeferredTransaction];
        }
        else {
            [[self db] beginTransaction];
        }
        
        block([self db], &shouldRollback);
        
        if (shouldRollback) {
            [[self db] rollback];
        }
        else {
            [[self db] commit];
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
        
        if ([[self db] startSavePointWithName:name error:&err]) {
            
            block([self db], &shouldRollback);
            
            if (shouldRollback) {
                [[self db] rollbackToSavePointWithName:name error:&err];
            }
            else {
                [[self db] releaseSavePointWithName:name error:&err];
            }
            
        }
    });
    
    return err;
}
#endif

@end
