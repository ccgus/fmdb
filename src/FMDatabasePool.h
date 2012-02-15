//
//  FMDatabasePool.h
//  fmdb
//
//  Created by August Mueller on 6/22/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "sqlite3.h"

/*

                         ***README OR SUFFER***
Before using FMDatabasePool, please consider using FMDatabaseQueue instead.

I'm also not 100% sold on this interface.  So if you use FMDatabasePool, things like
[[pool db] popFromPool] might go away.  In fact, I'm pretty darn sure they will.

If you really really really know what you're doing and FMDatabasePool is what
you really really need, OK you can use it.  But just be careful not to deadlock!

First, make your pool.

	FMDatabasePool *pool = [FMDatabasePool databasePoolWithPath:aPath];

If you just have a single statement- use it like so:

	[[pool db] executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:42]];

The pool's db method will return an instance of FMDatabase that knows it is in a pool.  After it is done with the update, it will place itself back into the pool.

Making a query is similar:
	
	FMResultSet *rs = [[pool db] executeQuery:@"SELECT * FROM myTable"];
	while ([rs next]) {
		//retrieve values for each record
	}

When the result set is exhausted or [rs close] is called, the result set will tell the database it was created from to put itself back into the pool for use later on.

If you'd rather use multiple queries without having to call [pool db] each time, you can grab a database instance, tell it to stay out of the pool, and then tell it to go back in the pool when you're done:

	FMDatabase *db = [[pool db] popFromPool];
	…
	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:1]];
	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:2]];
	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:3]];
	…
	// put the database back in the pool.
	[db pushToPool];

Alternatively, you can use this nifty block based approach:

	[dbPool useDatabase: ^(FMDatabase *aDb) {
		[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:1]];
		[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:2]];
		[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:3]];
	}];

And it will do the right thing.

Starting a transaction will keep the db from going back into the pool automatically:

	FMDatabase *db = [pool db];
	[db beginTransaction];
	
	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:1]];
	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:2]];
	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:3]];
	
	[db commit]; // or a rollback here would work as well.
 

There is also a block based transaction approach:

	[dbPool inTransaction:^(FMDatabase *db, BOOL *rollback) {
		[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:1]];
		[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:2]];
		[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:3]];
    }];



If you check out a database, but never execute a statement or query, **you need to put it back in the pool yourself**.

	FMDatabase *db = [pool db];
	// lala, don't do anything with the database
	…
	// oh look, I BETTER PUT THE DB BACK IN THE POOL OR ELSE IT IS GOING TO LEAK:
	[db pushToPool];

*/









@class FMDatabase;

@interface FMDatabasePool : NSObject {
    NSString            *_path;
    
    dispatch_queue_t    _lockQueue;
    
    NSMutableArray      *_databaseInPool;
    NSMutableArray      *_databaseOutPool;
    
    __unsafe_unretained id _delegate;
    
    NSUInteger          _maximumNumberOfDatabasesToCreate;
}

@property (retain) NSString *path;
@property (assign) id delegate;
@property (assign) NSUInteger maximumNumberOfDatabasesToCreate;

+ (id)databasePoolWithPath:(NSString*)aPath;
- (id)initWithPath:(NSString*)aPath;

- (NSUInteger)countOfCheckedInDatabases;
- (NSUInteger)countOfCheckedOutDatabases;
- (NSUInteger)countOfOpenDatabases;
- (void)releaseAllDatabases;

- (void)inDatabase:(void (^)(FMDatabase *db))block;

- (void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block;
- (void)inDeferredTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block;

#if SQLITE_VERSION_NUMBER >= 3007000
// NOTE: you can not nest these, since calling it will pull another database out of the pool and you'll get a deadlock.
// If you need to nest, use FMDatabase's startSavePointWithName:error: instead.
- (NSError*)inSavePoint:(void (^)(FMDatabase *db, BOOL *rollback))block;
#endif

@end


@interface NSObject (FMDatabasePoolDelegate)

- (BOOL)databasePool:(FMDatabasePool*)pool shouldAddDatabaseToPool:(FMDatabase*)database;

@end

