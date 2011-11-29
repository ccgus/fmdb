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
        
        _queue = dispatch_queue_create([[NSString stringWithFormat:@"fmdb.%@", self] UTF8String], NULL);
	}
    
	return self;
}

- (void)dealloc {
    
    [_db release];
    
    if (_queue) {
        dispatch_release(_queue);
        _queue = 0x00;
    }
    
    [super dealloc];
}

- (void)inDatabase:(void (^)(FMDatabase *db))block {
    
    dispatch_sync(_queue, ^() { block(_db); });
}

- (void)beginTransaction:(BOOL)useDeferred withBlock:(void (^)(FMDatabase *db, BOOL *rollback))block {
    
    dispatch_sync(_queue, ^() { 
        
        BOOL shouldRollback = NO;
        
        if (useDeferred) {
            [_db beginDeferredTransaction];
        }
        else {
            [_db beginTransaction];
        }
        
        block(_db, &shouldRollback);
        
        if (shouldRollback) {
            [_db rollback];
        }
        else {
            [_db commit];
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
        
        if ([_db startSavePointWithName:name error:&err]) {
            
            block(_db, &shouldRollback);
            
            if (shouldRollback) {
                [_db rollbackToSavePointWithName:name error:&err];
            }
            else {
                [_db releaseSavePointWithName:name error:&err];
            }
            
        }
    });
    
    return err;
}
#endif

@end
