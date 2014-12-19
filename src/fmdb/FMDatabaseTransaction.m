//
//  FMDatabaseTransaction.m
//  LayerKit
//
//  Created by Blake Watters on 12/18/14.
//  Copyright (c) 2014 Layer Inc. All rights reserved.
//

#import "FMDatabaseTransaction.h"

@interface FMDatabaseTransaction ()
@property (nonatomic) FMDatabase *database;
@property (nonatomic) dispatch_semaphore_t semaphore;
@property (nonatomic) NSRecursiveLock *lock;
@property (nonatomic, copy) void (^completionBlock)(BOOL isCommitted, NSError *error);
@property (nonatomic) BOOL openedTransaction;
@end

@implementation FMDatabaseTransaction

+ (instancetype)transactionWithDatabase:(FMDatabase *)database semaphore:(dispatch_semaphore_t)semaphore
{
    return [[self alloc] initWithDatabase:database semaphore:semaphore];
}

- (id)initWithDatabase:(FMDatabase *)database semaphore:(dispatch_semaphore_t)semaphore
{
    NSParameterAssert(database);
    NSParameterAssert(semaphore);
    self = [super init];
    if (self) {
        _database = database;
        _semaphore = semaphore;
        _lock = [NSRecursiveLock new];
        _lock.name = [NSString stringWithFormat:@"LYRDatabaseTransaction Lock %p", self];
        _openedTransaction = NO;
    }
    return self;
}

- (id)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Failed to call designated initializer." userInfo:nil];
}

- (void)dealloc
{
    // Only signal and dispatch completion if we opened the transaction
    if (_openedTransaction) {
        if (_semaphore) {
            if (self.isOpen) {
                [self rollback:nil];
            } else {
                dispatch_semaphore_signal(_semaphore);
                [self signalCompletionWithSuccess:NO error:nil];
            }
        } else {
            [self signalCompletionWithSuccess:NO error:nil];
        }
    }
}

- (BOOL)performTransactionWithBlock:(void (^)(FMDatabase *database, BOOL *shouldRollback))transactionBlock
{
    if (!transactionBlock) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Failed to perform a transaction with a nil block." userInfo:nil];
    }
    
    // Begin transaction
    BOOL success = [self open:YES error:nil];
    if (!success) {
        return NO;
    }
    
    // Execute transaction block
    BOOL shouldRollback = NO;
    transactionBlock(_database, &shouldRollback);
    
    // Check if rollback is needed
    if (shouldRollback) {
        success = [self rollback:nil];
    } else {
        success = [self commit:nil];
    }
    return success;
}

- (BOOL)open:(BOOL)deferred error:(NSError **)error
{
    if (!_semaphore) @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"No semaphore available: database transaction objects cannot be reused." userInfo:nil];
    if (!_database) @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"No database available: database transaction objects cannot be reused." userInfo:nil];
    
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    [self.lock lock];
    if (self.database.inTransaction) @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot open transaction because it has already been opened." userInfo:nil];
    BOOL success = deferred ? [_database beginDeferredTransaction] : [_database beginTransaction];
    if (success) {
        self.openedTransaction = YES;
    } else {
        if (error) {
            *error = [self.database lastError];
        }
        dispatch_semaphore_signal(_semaphore);
    }
    [self.lock unlock];
    return success;
}

- (FMDatabase *)database
{
    if (self.isOpen) {
        return _database;
    } else {
        return nil;
    }
}

- (BOOL)isOpen
{
    [self.lock lock];
    BOOL isOpen = self.openedTransaction && _database.inTransaction;
    [self.lock unlock];
    return isOpen;
}

- (void)releaseDatabase
{
    [_database closeOpenResultSets];
    _database = nil;
    _isComplete = YES;
    dispatch_semaphore_signal(_semaphore);
    _semaphore = nil;
}

- (BOOL)commit:(NSError **)error
{
    if (!_semaphore) @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"No semaphore available: database transaction has already been committed/rolled back." userInfo:nil];
    if (!_database) @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"No database available: database transaction has already been committed/rolled back." userInfo:nil];
    
    [self.lock lock];
    if (!self.isOpen) @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot commit transaction because it is not open." userInfo:nil];
    NSError *outError = nil;
    BOOL success = [_database commit];
    if (!success) {
        outError = [_database lastError];
    }
    [self releaseDatabase];
    [self.lock unlock];
    if (success) {
        [self signalCompletionWithSuccess:YES error:nil];
    } else {
        [self signalCompletionWithSuccess:YES error:outError];
    }
    if (error) {
        *error = outError;
    }
    return success;
}

- (BOOL)rollback:(NSError **)error
{
    if (!_semaphore) @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"No semaphore available: database transaction has already been committed/rolled back." userInfo:nil];
    if (!_database) @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"No database available: database transaction has already been committed/rolled back." userInfo:nil];
    
    [self.lock lock];
    if (!self.isOpen) @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Cannot rollback transaction because it is not open." userInfo:nil];
    NSError *outError = nil;
    BOOL success = [_database rollback];
    if (!success) {
        outError = [_database lastError];
    }
    [self releaseDatabase];
    [self.lock unlock];
    if (success) {
        [self signalCompletionWithSuccess:NO error:nil];
    } else {
        [self signalCompletionWithSuccess:NO error:outError];
    }
    if (error) {
        *error = outError;
    }
    return success;
}

- (void)setCompletionBlock:(void (^)(BOOL isCommitted, NSError *error))completionBlock
{
    _completionBlock = [completionBlock copy];
}

- (void)signalCompletionWithSuccess:(BOOL)success error:(NSError *)error
{
    if (self.completionBlock) {
        self.completionBlock(success, error);
        self.completionBlock = nil;
    }
}

@end
