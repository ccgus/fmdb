//
//  FMDatabaseQueue.h
//  fmdb
//
//  Created by August Mueller on 6/22/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "sqlite3.h"

@class FMDatabase;

/** To perform queries and updates on multiple threads, you'll want to use `FMDatabaseQueue`.

 Using a single instance of `<FMDatabase>` from multiple threads at once is a bad idea.  It has always been OK to make a `<FMDatabase>` object *per thread*.  Just don't share a single instance across threads, and definitely not across multiple threads at the same time.

 Instead, use `FMDatabaseQueue`. Here's how to use it:

 First, make your queue.

    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:aPath];

 Then use it like so:

    [queue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:1]];
        [db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:2]];
        [db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:3]];

        FMResultSet *rs = [db executeQuery:@"select * from foo"];
        while ([rs next]) {
            //…
        }
    }];

 An easy way to wrap things up in a transaction can be done like this:

    [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:1]];
        [db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:2]];
        [db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:3]];

        if (whoopsSomethingWrongHappened) {
            *rollback = YES;
            return;
        }
        // etc…
        [db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:4]];
    }];

 `FMDatabaseQueue` will run the blocks on a concurrent queue (hence the name of the class) in a fasion of `Multiple Readers, Single Writer`.  All Readers blocks will run concurrently but Writer blocks will block other blocks in the queue (barrier block).

 ### See also

 - `<FMDatabase>`

 @warning Do not instantiate a single `<FMDatabase>` object and use it across multiple threads. Use `FMDatabaseQueue` instead.
 
 @warning The calls to `FMDatabaseQueue`'s default methods are blocking.  So even though you are passing along blocks, they will **not** be run on another thread.  By the way, we provide the asynchronous methods too.
 @warning We are not provide nested calling support. If you perform writer operation/transaction inside the reader one, that operation/transaction will be performed as reader operation/transaction but it won't be dead lock. Please be careful for this case.

 */

typedef void(^FMDatabaseOperationBlock)(FMDatabase *db);
typedef void(^FMDatabaseTransactionBlock)(FMDatabase *db, BOOL *rollback);
typedef void(^FMDatabaseCompletionBlock)(BOOL success, NSError *error);
                                           

@interface FMDatabaseQueue : NSObject {
    NSString            *_path;
    dispatch_queue_t    _queue;
    FMDatabase          *_db;
}

@property (atomic, retain) NSString *path;
@property (nonatomic, readonly, strong) FMDatabase *database;

///----------------------------------------------------
/// @name Initialization, opening, and closing of queue
///----------------------------------------------------

/** Create queue using path.
 
 @param aPath The file path of the database.
 
 @return The `FMDatabaseQueue` object. `nil` on error.
 */

+ (instancetype)databaseQueueWithPath:(NSString*)aPath;

/** Create queue using path.

 @param aPath The file path of the database.

 @return The `FMDatabaseQueue` object. `nil` on error.
 */

- (instancetype)initWithPath:(NSString*)aPath;

/** Close database used by queue. */

- (void)close;

///-----------------------------------------------
/// @name Dispatching database operations to queue
///-----------------------------------------------

/** Synchronously perform database operations on queue.
 
 @param block The code to be run on the queue of `FMDatabaseQueue`
 */

- (void)inDatabase:(FMDatabaseOperationBlock)block;

/** Synchronously perform database operations on queue, using transactions.

 @param block The code to be run on the queue of `FMDatabaseQueue`
 */

- (void)inTransaction:(FMDatabaseTransactionBlock)block;

/** Synchronously perform database operations on queue, using deferred transactions.

 @param block The code to be run on the queue of `FMDatabaseQueue`
 */

- (void)inDeferredTransaction:(FMDatabaseTransactionBlock)block;


/** Synchronously perform reader database operations on queue.
 
 @param block The code to be run on the queue of `FMDatabaseQueue`
 */
- (void)performReaderOperation:(FMDatabaseOperationBlock)block;


/** Synchronously perform writer database operations on queue.
 
 @param block The code to be run on the queue of `FMDatabaseQueue`
 */
- (void)performWriterOperation:(FMDatabaseOperationBlock)block;


/** Synchronously perform reader database transactions on queue.
 
 @param error If the transactions cannot be init, commit of rollback, upon return contains an instance of NSError that describes the problem.
 @param block The code to be run on the queue of `FMDatabaseQueue`
 @return `YES` on success; `NO` on failure.
 */
- (BOOL)performReaderTransactionWithError:(NSError * __autoreleasing *)error
                               usingBlock:(FMDatabaseTransactionBlock)block;


/** Synchronously perform writer database transactions on queue.
 
 @param error If the transactions cannot be init, commit of rollback, upon return contains an instance of NSError that describes the problem.
 @param block The code to be run on the queue of `FMDatabaseQueue`
 @return `YES` on success; `NO` on failure.
 */
- (BOOL)performWriterTransactionWithError:(NSError * __autoreleasing *)error
                               usingBlock:(FMDatabaseTransactionBlock)block;


/** Synchronously perform deferred reader database transactions on queue.
 
 @param error If the transactions cannot be init, commit of rollback, upon return contains an instance of NSError that describes the problem.
 @param block The code to be run on the queue of `FMDatabaseQueue`
 @return `YES` on success; `NO` on failure.
 */
- (BOOL)performReaderDeferredTransactionWithError:(NSError * __autoreleasing *)error
                                       usingBlock:(FMDatabaseTransactionBlock)block;


/** Synchronously perform deferred writer database transactions on queue.
 
 @param error If the transactions cannot be init, commit of rollback, upon return contains an instance of NSError that describes the problem.
 @param block The code to be run on the queue of `FMDatabaseQueue`
 @return `YES` on success; `NO` on failure.
 */
- (BOOL)performWriterDeferredTransactionWithError:(NSError * __autoreleasing *)error
                                       usingBlock:(FMDatabaseTransactionBlock)block;


/** Asynchronously perform reader database transaction on queue.
 
 @param block The code to be run on the queue of `FMDatabaseQueue`
 */
- (void)performAsynchronouslyReaderOperation:(FMDatabaseOperationBlock)block;


/** Asynchronously perform writer database transaction on queue.
 
 @param block The code to be run on the queue of `FMDatabaseQueue`
 */
- (void)performAsynchronouslyWriterOperation:(FMDatabaseOperationBlock)block;


/** Asynchronously perform reader database deferred transaction on queue.
 
 @param block The code to be run on the queue of `FMDatabaseQueue`
 */
- (void)performAsynchronouslyReaderDeferredTransaction:(FMDatabaseTransactionBlock)block;


/** Asynchronously perform writer database deferred transaction on queue.
 
 @param block The code to be run on the queue of `FMDatabaseQueue`
 */
- (void)performAsynchronouslyWriterDeferredTransaction:(FMDatabaseTransactionBlock)block;


/** Asynchronously perform reader database transactions on queue.
 
 @param block The code to be run on the queue of `FMDatabaseQueue`
 @param completion The completion hanlder block to be run when the transaction block is completed.  The block parameters are as follows:
   @param success Boolean indicates that the transaction operation is succes or not.
   @param error Error describe the transaction operation problem, if any.
 */
- (void)performAsynchronouslyReaderTransaction:(FMDatabaseTransactionBlock)block
                                    completion:(FMDatabaseCompletionBlock)completion;

/** Asynchronously perform writer database transactions on queue.
 
 @param block The code to be run on the queue of `FMDatabaseQueue`
 @param completion The completion hanlder block to be run when the transaction block is completed.  The block parameters are as follows:
 @param success Boolean indicates that the transaction operation is succes or not.
 @param error Error describe the transaction operation problem, if any.
 */
- (void)performAsynchronouslyWriterTransaction:(FMDatabaseTransactionBlock)block
                                    completion:(FMDatabaseCompletionBlock)completion;

/** Asynchronously perform reader database deferred transactions on queue.
 
 @param block The code to be run on the queue of `FMDatabaseQueue`
 @param completion The completion hanlder block to be run when the transaction block is completed.  The block parameters are as follows:
 @param success Boolean indicates that the transaction operation is succes or not.
 @param error Error describe the transaction operation problem, if any.
 */
- (void)performAsynchronouslyReaderDeferredTransaction:(FMDatabaseTransactionBlock)block
                                            completion:(FMDatabaseCompletionBlock)completion;

/** Asynchronously perform writer database deferred transactions on queue.
 
 @param block The code to be run on the queue of `FMDatabaseQueue`
 @param completion The completion hanlder block to be run when the transaction block is completed.  The block parameters are as follows:
 @param success Boolean indicates that the transaction operation is succes or not.
 @param error Error describe the transaction operation problem, if any.
 */
- (void)performAsynchronouslyWriterDeferredTransaction:(FMDatabaseTransactionBlock)block
                                            completion:(FMDatabaseCompletionBlock)completion;



///-----------------------------------------------
/// @name Dispatching database operations to queue
///-----------------------------------------------

/** Synchronously perform database operations using save point.

 @param block The code to be run on the queue of `FMDatabaseQueue`
 */

#if SQLITE_VERSION_NUMBER >= 3007000
// NOTE: you can not nest these, since calling it will pull another database out of the pool and you'll get a deadlock.
// If you need to nest, use FMDatabase's startSavePointWithName:error: instead.
- (NSError*)inSavePoint:(void (^)(FMDatabase *db, BOOL *rollback))block;
#endif

@end

