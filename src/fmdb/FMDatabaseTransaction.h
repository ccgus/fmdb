//
//  FMDatabaseTransaction.h
//  LayerKit
//
//  Created by Blake Watters on 12/18/14.
//  Copyright (c) 2014 Layer Inc. All rights reserved.
//

#import <FMDB/FMDB.h>

/**
 @abstract The `FMDatabaseTransaction` class models a SQLite database transaction as an object. Write access is brokered via a semaphore.
 @discussion The `FMDatabaseTransaction` object is an interface for mediating threaded access to a single writable database instance. The semaphore
 guarantees that only a single consumer can access the database at a time without requiring the use of blocks to mediate access. Note that transaction
 objects are single use. Attempting to reuse a transaction object after it has been committed or rolled back is programmer error and will result in a
 runtime exception being raised.
 */
@interface FMDatabaseTransaction : NSObject

///--------------------------------------
/// @name Creating a Database Transaction
///--------------------------------------

/**
 @abstract Creates and returns a new transaction for the given database. A shared semaphore with a count of 1 must be used to broker access
 between all transaction objects.
 @param database The writable database to create a transaction against.
 @param semaphore A Grand Central Dispatch counting semaphore used to broker access to the database.
 @return A newly created database transaction object.
 */
+ (instancetype)transactionWithDatabase:(FMDatabase *)database semaphore:(dispatch_semaphore_t)semaphore;

/**
 @abstract Returns the database the transaction is bound to or `nil` if it has not yet been opened.
 @discussion It is not safe to utilize the database reference until the transaction has been opened. The accessor will return `nil` until the transaction is opened.
 */
@property (nonatomic, readonly) FMDatabase *database;

///-----------------------------------
/// @name Inspecting Transaction State
///-----------------------------------

/**
 @abstract Returns a Boolean value that indicates if the transaction has been opened.
 @discussion The transaction is only considered opened if the underlying database is in a transaction and the receiver opened the transaction.
 */
@property (nonatomic, readonly) BOOL isOpen;

/**
 @abstract Returns a Boolean value that indicates if the transaction is complete (from being committed or rolled back).
 */
@property (nonatomic, readonly) BOOL isComplete;

///------------------------------------------
/// @name Opening and Closing the Transaction
///------------------------------------------

/**
 @abstract Opens the database transaction, gaining exclusive write access to the connection.
 @param deferred A Boolean value that determine if an exclusive or a deferred transaction is opened.
 @param error A pointer to an error object that is set upon failure to open the transaction.
 @return A Boolean value that indicates if the transaction was successfully opened.
 */
- (BOOL)open:(BOOL)deferred error:(NSError **)error;

/**
 @abstract Commits an open transaction.
 @param error A pointer to an error object that is set upon failure to commit the transaction.
 @return A Boolean value that indicates if the transaction was committed successfully.
 */
- (BOOL)commit:(NSError **)error;

/**
 @abstract Rolls back an open transaction.
 @param error A pointer to an error object that is set upon failure to roll back the transaction.
 @return A Boolean value that indicates if the transaction was rolled back successfully.
 */
- (BOOL)rollback:(NSError **)error;

///------------------------------------------
/// @name Executing a Transaction via a Block
///------------------------------------------

/**
 @abstract Executes the block in between a "transaction begin" and "transaction commit" statements.
 @param database Database reference.
 @param transactionBlock Transaction block with a `LYRDatabase` instance and a pointer to the `shouldRollback` switch.
 */
- (BOOL)performTransactionWithBlock:(void (^)(FMDatabase *database, BOOL *shouldRollback))transactionBlock;

///-------------------------------------
/// @name Configuring a Completion Block
///-------------------------------------

/**
 @abstract Sets a completion block that gets executed after the transaction has been commited, rolled back or aborted.
 @discussion If set, the completion block is guaranteed to be executed. If the transaction is aborted by falling out of scope then the completion block is invoked during `dealloc`.
 If the transaction is aborted, then the completion block is called with a `isCommitted` value of `NO` and a `nil` error.
 @param completion A block to executed upon completion of the transaction.
 */
- (void)setCompletionBlock:(void (^)(BOOL isCommitted, NSError *error))completionBlock;

@end
