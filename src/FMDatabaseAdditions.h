//
//  FMDatabaseAdditions.h
//  fmdb
//
//  Created by August Mueller on 10/30/05.
//  Copyright 2005 Flying Meat Inc.. All rights reserved.
//

#import <Foundation/Foundation.h>

/** Category of additions for `<FMDatabase>` class.
 */

@interface FMDatabase (FMDatabaseAdditions)

///---------------------------------------------------------------------------------------
/// @name Return results of SQL to variable
///---------------------------------------------------------------------------------------

/** Return `int` value for query
 
 @param query The SQL query to be performed. 
 @param ... A list of parameters that will be bound to the `?` placeholders in the SQL query.

 @return `int` value.
 */

- (int)intForQuery:(NSString*)query, ...;

/** Return `long` value for query

 @param query The SQL query to be performed.
 @param ... A list of parameters that will be bound to the `?` placeholders in the SQL query.

 @return `long` value.
 */

- (long)longForQuery:(NSString*)query, ...;

/** Return `BOOL` value for query

 @param query The SQL query to be performed.
 @param ... A list of parameters that will be bound to the `?` placeholders in the SQL query.

 @return `BOOL` value.
 */

- (BOOL)boolForQuery:(NSString*)query, ...;

/** Return `double` value for query

 @param query The SQL query to be performed.
 @param ... A list of parameters that will be bound to the `?` placeholders in the SQL query.

 @return `double` value.
 */

- (double)doubleForQuery:(NSString*)query, ...;

/** Return `NSString` value for query

 @param query The SQL query to be performed.
 @param ... A list of parameters that will be bound to the `?` placeholders in the SQL query.

 @return `NSString` value.
 */

- (NSString*)stringForQuery:(NSString*)query, ...;

/** Return `NSData` value for query

 @param query The SQL query to be performed.
 @param ... A list of parameters that will be bound to the `?` placeholders in the SQL query.

 @return `NSData` value.
 */

- (NSData*)dataForQuery:(NSString*)query, ...;

/** Return `NSDate` value for query

 @param query The SQL query to be performed.
 @param ... A list of parameters that will be bound to the `?` placeholders in the SQL query.

 @return `NSDate` value.
 */

- (NSDate*)dateForQuery:(NSString*)query, ...;


// Notice that there's no dataNoCopyForQuery:.
// That would be a bad idea, because we close out the result set, and then what
// happens to the data that we just didn't copy?  Who knows, not I.


///---------------------------------------------------------------------------------------
/// @name Schema related operations
///---------------------------------------------------------------------------------------

/** Does table exist in database?

 @param tableName The name of the table being looked for.

 @return `YES` if table found; `NO` if not found.
 */

- (BOOL)tableExists:(NSString*)tableName;

/** The schema of the database.
 
 This will be the schema for the entire database.

 @return `FMResultSet` of schema; `nil` on error.
 */

- (FMResultSet*)getSchema;

/** The schema of the database.

 This will be the schema for a particular table as report by SQLite `PRAGMA`:
 
    PRAGMA table_info('%@')

 @param tableName The name of the table for whom the schema will be returned.
 
 @return `FMResultSet` of schema; `nil` on error.
 */

- (FMResultSet*)getTableSchema:(NSString*)tableName;

/** Test to see if particular column exists for particular table in database
 
 @param columnName The name of the column.
 
 @param tableName The name of the table.
 
 @return `YES` if column exists in table in question; `NO` otherwise.
 */

- (BOOL)columnExists:(NSString*)columnName inTableWithName:(NSString*)tableName;

/** Test to see if particular column exists for particular table in database

 @param columnName The name of the column.

 @param tableName The name of the table.

 @return `YES` if column exists in table in question; `NO` otherwise.
 
 @warning Deprecated - use `<columnExists:inTableWithName:>` instead.
 
 @see columnExists:inTableWithName:
 */

- (BOOL)columnExists:(NSString*)tableName columnName:(NSString*)columnName __attribute__ ((deprecated));


/** Validate SQL statement
 
 This validates SQL statement by performing `sqlite3_prepare_v2`, but not returning the results, but instead immediately calling `sqlite3_finalize`.
 
 @param sql The SQL statement being validated.
 
 @param error This is a pointer to a `NSError` object that will receive the autoreleased `NSError` object if there was any error. If this is `nil`, no `NSError` result will be returned.
 
 @return `YES` if validation succeeded without incident; `NO` otherwise.
 
 */

- (BOOL)validateSQL:(NSString*)sql error:(NSError**)error;


#if SQLITE_VERSION_NUMBER >= 3007017

///---------------------------------------------------------------------------------------
/// @name Application identifier tasks
///---------------------------------------------------------------------------------------

/** Retrieve application ID
 
 @return The `uint32_t` numeric value of the application ID.
 
 @see setApplicationID:
 */

- (uint32_t)applicationID;

/** Set the application ID

 @param appID The `uint32_t` numeric value of the application ID.
 
 @see applicationID
 */

- (void)setApplicationID:(uint32_t)appID;

/** Retrieve application ID string

 @return The `NSString` value of the application ID.

 @see setApplicationIDString:
 */

- (NSString*)applicationIDString;

/** Set the application ID string

 @param string The `NSString` value of the application ID.

 @see applicationIDString
 */

- (void)setApplicationIDString:(NSString*)string;
#endif


@end
