//
//  FMReadOnlyDatabasePool.h
//  LayerKit
//
//  Created by Blake Watters on 12/18/14.
//  Copyright (c) 2014 Layer Inc. All rights reserved.
//

#import <FMDB/FMDB.h>

/*
 @abstract The `FMReadOnlyDatabasePool` class provides a factory of database
 transactions while maintaining a finite pool of database connections.
 */
@interface FMReadOnlyDatabasePool : NSObject <NSFastEnumeration>

/**
 @abstract Creates and returns a database pool with a given number of database connections.
 @discussion This method takes care of initializing and opening multiple database connections with given flags and puts them in a managed pool.
 @param path The path to the database on disk. Passing `nil` causes an exception.
 @param flags Flags that get passed down to the sqlite3_open function call.
 @param numberOfDatabases Pool size with the number of open database connection.
 @return A newly construct database pool manager object initialized with a given number of database connections.
 */
+ (instancetype)databasePoolWithPath:(NSString *)path flags:(int)flags capacity:(NSUInteger)numberOfDatabases;

///------------------------------------------------
/// @name Inspecting Pool Capacity and Availability
///------------------------------------------------

/**
 @abstract Returns the number of databases in the pool.
 */
@property (nonatomic, readonly) NSUInteger numberOfDatabases;

/**
 @abstract Returns the number of databases available for utilization in the pool (from the maximum of `numberOfDatabases`).
 */
@property (nonatomic, readonly) NSUInteger numberOfAvailableDatabases;

///------------------------------------
/// @name Acquiring Available Databases
///------------------------------------

/**
 @abstract Returns an available database from the pool. The database connection will not be vended to any other listener as long as the returned reference
 is kept alive by the caller.
 @return An available read-only database connection or `nil` if none is available.
 */
- (FMDatabase *)availableDatabase;

/**
 @abstract Blocks the caller until a databases connection is available.
 @return An available read-only database connection.
 */
- (FMDatabase *)waitForAvailableDatabase;

///-------------------------------------
/// @name Explicitly Releasing Databases
///-------------------------------------

/**
 @abstract Explicitly releases the given database back to the pool.
 @discussion After invoking this method the caller must guarantee that it will no longer execute any queries against the database object as it will be immediately returned to the available connection pool and may be vended to another consumer.
 */
- (void)releaseDatabase:(FMDatabase *)database;

///-------------------------------
/// @name Block Convenience Method
///-------------------------------

/**
 @abstract Acquires an available database and yields it to the block for usage, returning it to the pool after the block has completed.
 @param block A block object to execute once a database connection has been acquired. The block has no return value and accepts a single argument: 
 */
- (void)inDatabase:(void (^)(FMDatabase *database))block;

@end
