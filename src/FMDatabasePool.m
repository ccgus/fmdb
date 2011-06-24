//
//  FMDatabasePool.m
//  fmdb
//
//  Created by August Mueller on 6/22/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import "FMDatabasePool.h"
#import "FMDatabase.h"

@implementation FMDatabasePool
@synthesize path=_path;
@synthesize delegate=_delegate;
@synthesize maximumNumberOfDatabasesToCreate=_maximumNumberOfDatabasesToCreate;


+ (id)databasePoolWithPath:(NSString*)aPath {
    return [[[self alloc] initWithPath:aPath] autorelease];
}

- (id)initWithPath:(NSString*)aPath {
	
    self = [super init];
    
	if (self != nil) {
        _path               = [aPath copy];
        _lockQueue          = dispatch_queue_create([[NSString stringWithFormat:@"fmdb.%@", self] UTF8String], NULL);
        _databaseInPool     = [[NSMutableArray array] retain];
        _databaseOutPool    = [[NSMutableArray array] retain];
	}
    
	return self;
}

- (void)dealloc {
    
    _delegate = 0x00;
    
    [_path release];
    [_databaseInPool release];
    [_databaseOutPool release];
    
    if (_lockQueue) {
        dispatch_release(_lockQueue);
        _lockQueue = 0x00;
    }
    
    [super dealloc];
}


- (void)executeLocked:(void (^)(void))aBlock {
    dispatch_sync(_lockQueue, aBlock);
}

- (void)pushDatabaseBackInPool:(FMDatabase*)db {
    
    [self executeLocked:^() {
        
        if ([_databaseInPool containsObject:db]) {
            [[NSException exceptionWithName:@"Database already in pool" reason:@"The FMDatabase being put back into the pool is already present in the pool" userInfo:nil] raise];
        }
        
        [_databaseInPool addObject:db];
        [_databaseOutPool removeObject:db];
        
        [db setPool:0x00];
        
    }];
}

- (FMDatabase*)db {
    
    __block FMDatabase *db;
    
    [self executeLocked:^() {
        db = [_databaseInPool lastObject];
        
        if (db) {
            [_databaseOutPool addObject:db];
            [_databaseInPool removeLastObject];
        }
        else {
            
            if (_maximumNumberOfDatabasesToCreate) {
                NSUInteger currentCount = [_databaseOutPool count] + [_databaseInPool count];
                
                if (currentCount >= _maximumNumberOfDatabasesToCreate) {
                    NSLog(@"Maximum number of databases (%ld) has already been reached!", (long)currentCount);
                    return;
                }
            }
            
            db = [FMDatabase databaseWithPath:_path];
            
            if ([db open]) {
                if ([_delegate respondsToSelector:@selector(databasePool:shouldAddDatabaseToPool:)] && ![_delegate databasePool:self shouldAddDatabaseToPool:db]) {
                    [db close];
                    db = 0x00;
                }
                else {
                    [_databaseOutPool addObject:db];
                }
            }
            else {
                NSLog(@"Could not open up the database at path %@", _path);
                db = 0x00;
            }
        }
        
        [db setPool:self];
    }];
    
    return db;
}

- (NSUInteger)countOfCheckedInDatabases {
    
    __block NSInteger count;
    
    [self executeLocked:^() {
        count = [_databaseInPool count];
    }];
    
    return count;
}

- (NSUInteger)countOfCheckedOutDatabases {
    
    __block NSInteger count;
    
    [self executeLocked:^() {
        count = [_databaseOutPool count];
    }];
    
    return count;
}

- (NSUInteger)countOfOpenDatabases {
    __block NSInteger count;
    
    [self executeLocked:^() {
        count = [_databaseOutPool count] + [_databaseInPool count];
    }];
    
    return count;
}

- (void)releaseAllDatabases {
    [self executeLocked:^() {
        [_databaseOutPool removeAllObjects];
        [_databaseInPool removeAllObjects];
    }];
}

- (void)inDatabase:(void (^)(FMDatabase *db))block {
    
    FMDatabase *db = [[self db] popFromPool];
    
    block(db);
    
    [db pushToPool];
}

- (void)beginTransaction:(BOOL)useDeferred withBlock:(void (^)(FMDatabase *db, BOOL *rollback))block {
    
    BOOL shouldRollback = NO;
    
    FMDatabase *db = [self db];
    
    if (useDeferred) {
        [db beginDeferredTransaction];
    }
    else {
        [db beginTransaction];
    }
    
    
    block(db, &shouldRollback);
    
    if (shouldRollback) {
        [db rollback];
    }
    else {
        [db commit];
    }
}

- (void)inDeferredTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block {
    [self beginTransaction:YES withBlock:block];
}

- (void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block {
    [self beginTransaction:NO withBlock:block];
}

- (NSError*)inSavePoint:(void (^)(FMDatabase *db, BOOL *rollback))block {
    
    static unsigned long savePointIdx = 0;
    
    NSString *name = [NSString stringWithFormat:@"savePoint%ld", savePointIdx++];
    
    BOOL shouldRollback = NO;
    
    FMDatabase *db = [self db];
    
    NSError *err = 0x00;
    
    if (![db startSavePointWithName:name error:&err]) {
        return err;
    }
    
    block(db, &shouldRollback);
    
    if (shouldRollback) {
        [db rollbackToSavePointWithName:name error:&err];
    }
    else {
        [db releaseSavePointWithName:name error:&err];
    }
    
    return err;
}


@end
