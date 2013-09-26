//
//  FMDatabaseQueue.m
//  fmdb
//
//  Created by August Mueller on 6/22/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import "FMDatabaseQueue.h"
#import "FMDatabase.h"

/*
 
 Note: we call [self retain]; before using dispatch_sync, just incase 
 FMDatabaseQueue is released on another thread and we're in the middle of doing
 something in dispatch_sync
 
 */

static const void * const FMDatabaseQueueGCDKey = &FMDatabaseQueueGCDKey;

@implementation FMDatabaseQueue

@synthesize path = _path;

+ (instancetype)databaseQueueWithPath:(NSString*)aPath {
    
    FMDatabaseQueue *q = [[self alloc] initWithPath:aPath];
    
    FMDBAutorelease(q);
    
    return q;
}

- (instancetype)initWithPath:(NSString*)aPath {
    
    self = [super init];
    
    if (self != nil) {
        
        _db = [FMDatabase databaseWithPath:aPath];
        _db.allowsMultiThread = YES;
        FMDBRetain(_db);
        
        if (![_db openWithFlags:(SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX)]) {
            NSLog(@"Could not create database queue for path %@", aPath);
            FMDBRelease(self);
            return 0x00;
        }
        
        _path = FMDBReturnRetained(aPath);
        
        _queue = dispatch_queue_create([[NSString stringWithFormat:@"fmdb.%@", self] UTF8String], DISPATCH_QUEUE_CONCURRENT);
        dispatch_queue_set_specific(_queue, FMDatabaseQueueGCDKey, (__bridge void *)self, NULL);
    }
    
    return self;
}

- (void)dealloc {
    
    FMDBRelease(_db);
    FMDBRelease(_path);
    
    if (_queue) {
        FMDBDispatchQueueRelease(_queue);
        _queue = 0x00;
    }
#if ! __has_feature(objc_arc)
    [super dealloc];
#endif
}

- (void)close {
    FMDBRetain(self);
    dispatch_block_t work = ^{
        [_db close];
        FMDBRelease(_db);
        _db = 0x00;
    };

    if (dispatch_get_specific(FMDatabaseQueueGCDKey) == (__bridge void *)(self)) {
        work();
    }
    else {
        dispatch_barrier_sync(_queue, work);
    }
    FMDBRelease(self);
}

- (FMDatabase*)database {
    if (!_db) {
        _db = FMDBReturnRetained([FMDatabase databaseWithPath:_path]);
        
        if (![_db openWithFlags:(SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX)]) {
            NSLog(@"FMDatabaseQueue could not reopen database for path %@", _path);
            FMDBRelease(_db);
            _db  = 0x00;
            return 0x00;
        }
    }
    
    return _db;
}


#pragma mark - Operation Methods

- (void)inDatabase:(FMDatabaseOperationBlock)block {
    [self performWriterOperation:block];
}

- (void)performReaderOperation:(FMDatabaseOperationBlock)block {
    [self performDatabaseOperationWithSynchronously:YES
                                  isWriterOperation:NO
                                          operation:block];
}

- (void)performWriterOperation:(FMDatabaseOperationBlock)block {
    [self performDatabaseOperationWithSynchronously:YES
                                  isWriterOperation:YES
                                          operation:block];
}

- (void)performAsynchronouslyWriterOperation:(FMDatabaseOperationBlock)block {
    [self performDatabaseOperationWithSynchronously:NO
                                  isWriterOperation:YES
                                          operation:block];
}

- (void)performAsynchronouslyReaderOperation:(FMDatabaseOperationBlock)block {
    [self performDatabaseOperationWithSynchronously:NO
                                  isWriterOperation:NO
                                          operation:block];
}

- (void)performDatabaseOperationWithSynchronously:(BOOL)synchronously
                                isWriterOperation:(BOOL)isWritter
                                        operation:(FMDatabaseOperationBlock)block {
    FMDBRetain(self);
    
    dispatch_block_t work = ^{
        
        FMDatabase *db = [self database];
        block(db);
      
        if (isWritter && [db hasOpenResultSets]) {
            NSLog(@"Warning: there is at least one open result set around after performing [FMDatabaseQueue inDatabase:]");
        }
      
        FMDBRelease(self);
    };
    
    void (* dispatch_function)(dispatch_queue_t, dispatch_block_t) = NULL;
    if (!synchronously) {
        dispatch_function = isWritter ? dispatch_barrier_async : dispatch_async;
    }
    else if (dispatch_get_specific(FMDatabaseQueueGCDKey) != (__bridge void *)(self)) {
        dispatch_function = isWritter ? dispatch_barrier_sync : dispatch_sync;
    }
    
    if (dispatch_function) {
        dispatch_function(_queue, work);
    }
    else {
        // If we perform synchronously and are in the private queue, we will just invoke the block instead.
        work();
    }
}


#pragma mark - Transaction Methods

- (void)inDeferredTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block {
    [self performWriterDeferredTransaction:block];
}

- (void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block {
    [self performWriterTransaction:block];
}

- (void)performWriterTransaction:(FMDatabaseTransactionBlock)block {
    [self performWriterTransactionWithError:NULL usingBlock:block];
}

- (void)performWriterDeferredTransaction:(FMDatabaseTransactionBlock)block {
    [self performWriterDeferredTransactionWithError:NULL usingBlock:block];
}

- (BOOL)performWriterTransactionWithError:(NSError * __autoreleasing *)error
                               usingBlock:(FMDatabaseTransactionBlock)block {
    return [self performDatabaseTransactionWithDeffered:NO
                                      isWriterOperation:YES
                                                  error:error
                                             usingBlock:block];
}

- (BOOL)performWriterDeferredTransactionWithError:(NSError * __autoreleasing *)error usingBlock:(FMDatabaseTransactionBlock)block {
    return [self performDatabaseTransactionWithDeffered:YES
                                      isWriterOperation:YES
                                                  error:error
                                             usingBlock:block];
}

- (void)performAsynchronouslyWriterDeferredTransaction:(FMDatabaseTransactionBlock)block {
    [self performAsynchronouslyWriterDeferredTransaction:block completion:NULL];
}

- (void)performAsynchronouslyWriterTransaction:(FMDatabaseTransactionBlock)block completion:(FMDatabaseCompletionBlock)completion {
    [self performDatabaseTransactionAsynchronouslyWithDeffered:NO
                                             isWriterOperation:YES
                                                   transaction:block
                                                    completion:completion];
}

- (void)performAsynchronouslyWriterDeferredTransaction:(FMDatabaseTransactionBlock)block completion:(FMDatabaseCompletionBlock)completion {
    [self performDatabaseTransactionAsynchronouslyWithDeffered:YES
                                             isWriterOperation:YES
                                                   transaction:block
                                                    completion:completion];
}

- (BOOL)performDatabaseTransactionWithDeffered:(BOOL)useDeferred
                             isWriterOperation:(BOOL)isWritter
                                         error:(NSError * __autoreleasing *)error
                                    usingBlock:(FMDatabaseTransactionBlock)block {
    __block BOOL success = NO;
    FMDBRetain(self);
    dispatch_block_t work = ^{
        
        BOOL shouldRollback = NO;
        
        if (useDeferred) {
            success = [[self database] beginDeferredTransaction];
        }
        else {
            success = [[self database] beginTransaction];
        }
        
        if (success) {
            block([self database], &shouldRollback);
            
            if (shouldRollback) {
                success = [[self database] rollback];
            }
            else {
                success = [[self database] commit];
            }
        }
        
        if (!success && error) {
            *error = [[self database] lastError];
        }
    };
    
    
    if (dispatch_get_specific(FMDatabaseQueueGCDKey) == (__bridge void *)(self)) {
        work();
    }
    else if (isWritter) {
        dispatch_barrier_sync(_queue, work);
    }
    else {
        dispatch_sync(_queue, work);
    }
    
    FMDBRelease(self);
    
    return success;
}

- (void)performDatabaseTransactionAsynchronouslyWithDeffered:(BOOL)useDeferred
                                           isWriterOperation:(BOOL)isWriter
                                                 transaction:(FMDatabaseTransactionBlock)block
                                                  completion:(FMDatabaseCompletionBlock)completion {
    __block BOOL success = NO;
    __block NSError *error = nil;
    FMDBRetain(self);
    dispatch_block_t work = ^{
        
        BOOL shouldRollback = NO;
        
        if (useDeferred) {
            success = [[self database] beginDeferredTransaction];
        }
        else {
            success = [[self database] beginTransaction];
        }
        
        if (success) {
            block([self database], &shouldRollback);
            
            if (shouldRollback) {
                success = [[self database] rollback];
            }
            else {
                success = [[self database] commit];
            }
        }
        
        if (!success) {
            error = [[self database] lastError];
        }
        
        if (completion) {
            completion(success, error);
        }
      
        FMDBRelease(self);
    };
    
    
    if (dispatch_get_specific(FMDatabaseQueueGCDKey) == (__bridge void *)(self)) {
        work();
    }
    else if (isWriter) {
        dispatch_barrier_async(_queue, work);
    }
    else {
        dispatch_async(_queue, work);
    }
}

#if SQLITE_VERSION_NUMBER >= 3007000
- (NSError*)inSavePoint:(void (^)(FMDatabase *db, BOOL *rollback))block {
    
    static unsigned long savePointIdx = 0;
    __block NSError *err = 0x00;
    FMDBRetain(self);
    dispatch_block_t work = ^{
        
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
    };
    
    if (dispatch_get_specific(FMDatabaseQueueGCDKey) == (__bridge void *)(self)) {
        work();
    }
    else {
        dispatch_barrier_sync(_queue, work);
    }
    FMDBRelease(self);
    return err;
}
#endif

@end
