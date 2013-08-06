#import <Foundation/Foundation.h>
#import "sqlite3.h"
#import "FMResultSet.h"
#import "FMDatabasePool.h"


#if ! __has_feature(objc_arc)
    #define FMDBAutorelease(__v) ([__v autorelease]);
    #define FMDBReturnAutoreleased FMDBAutorelease

    #define FMDBRetain(__v) ([__v retain]);
    #define FMDBReturnRetained FMDBRetain

    #define FMDBRelease(__v) ([__v release]);

	#define FMDBDispatchQueueRelease(__v) (dispatch_release(__v));
#else
    // -fobjc-arc
    #define FMDBAutorelease(__v)
    #define FMDBReturnAutoreleased(__v) (__v)

    #define FMDBRetain(__v)
    #define FMDBReturnRetained(__v) (__v)

    #define FMDBRelease(__v)

	#if TARGET_OS_IPHONE
		// Compiling for iOS
		#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 60000
			// iOS 6.0 or later
			#define FMDBDispatchQueueRelease(__v)
		#else
			// iOS 5.X or earlier
			#define FMDBDispatchQueueRelease(__v) (dispatch_release(__v));
		#endif
	#else
		// Compiling for Mac OS X
		#if MAC_OS_X_VERSION_MIN_REQUIRED >= 1080     
			// Mac OS X 10.8 or later
			#define FMDBDispatchQueueRelease(__v)
		#else
			// Mac OS X 10.7 or earlier
			#define FMDBDispatchQueueRelease(__v) (dispatch_release(__v));
		#endif
	#endif
#endif

#if !__has_feature(objc_instancetype)
    #define instancetype id
#endif

/** A SQLite ([http://sqlite.org/](http://sqlite.org/)) Objective-C wrapper.
 
 ### Usage
 The three main classes in FMDB are:

 - `FMDatabase` - Represents a single SQLite database.  Used for executing SQL statements.
 - `<FMResultSet>` - Represents the results of executing a query on an `FMDatabase`.
 - `<FMDatabaseQueue>` - If you want to perform queries and updates on multiple threads, you'll want to use this class.

 ### See also
 
 - `<FMDatabasePool>` - A pool of `FMDatabase` objects.
 - `<FMStatement>` - A wrapper for `sqlite_stmt`.
 
 ### External links
 
 - [FMDB on GitHub](https://github.com/ccgus/fmdb) including introductory documentation
 - [SQLite web site](http://sqlite.org/)
 - [FMDB mailing list](http://groups.google.com/group/fmdb)
 - [SQLite FAQ](http://www.sqlite.org/faq.html)
 
 @warning Do not instantiate a single `FMDatabase` object and use it across multiple threads. Instead, use `<FMDatabaseQueue>`.

 */

@interface FMDatabase : NSObject  {
    
    sqlite3*            _db;
    NSString*           _databasePath;
    BOOL                _logsErrors;
    BOOL                _crashOnErrors;
    BOOL                _traceExecution;
    BOOL                _checkedOut;
    BOOL                _shouldCacheStatements;
    BOOL                _isExecutingStatement;
    BOOL                _inTransaction;
    int                 _busyRetryTimeout;
    
    NSMutableDictionary *_cachedStatements;
    NSMutableSet        *_openResultSets;
    NSMutableSet        *_openFunctions;

    NSDateFormatter     *_dateFormat;
}

///-----------------
/// @name Properties
///-----------------

/** Whether should trace execution */

@property (atomic, assign) BOOL traceExecution;

/** Whether checked out or not */

@property (atomic, assign) BOOL checkedOut;

/** Busy retry timeout */

@property (atomic, assign) int busyRetryTimeout;

/** Crash on errors */

@property (atomic, assign) BOOL crashOnErrors;

/** Logs errors */

@property (atomic, assign) BOOL logsErrors;

/** Dictionary of cached statements */

@property (atomic, retain) NSMutableDictionary *cachedStatements;

///---------------------
/// @name Initialization
///---------------------

/** Create a `FMDatabase` object.
 
 An `FMDatabase` is created with a path to a SQLite database file.  This path can be one of these three:

 1. A file system path.  The file does not have to exist on disk.  If it does not exist, it is created for you.
 2. An empty string (`@""`).  An empty database is created at a temporary location.  This database is deleted with the `FMDatabase` connection is closed.
 3. `nil`.  An in-memory database is created.  This database will be destroyed with the `FMDatabase` connection is closed.

 For example, to create/open a database in your Mac OS X `tmp` folder:

    FMDatabase *db = [FMDatabase databaseWithPath:@"/tmp/tmp.db"];

 Or, in iOS, you might open a database in the app's `Documents` directory:

    NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *dbPath   = [docsPath stringByAppendingPathComponent:@"test.db"];
    FMDatabase *db     = [FMDatabase databaseWithPath:dbPath];

 (For more information on temporary and in-memory databases, read the sqlite documentation on the subject: [http://www.sqlite.org/inmemorydb.html](http://www.sqlite.org/inmemorydb.html))

 @param inPath Path of database file

 @return `FMDatabase` object if successful; `nil` if failure.

 */

+ (instancetype)databaseWithPath:(NSString*)inPath;

/** Initialize a `FMDatabase` object.
 
 An `FMDatabase` is created with a path to a SQLite database file.  This path can be one of these three:

 1. A file system path.  The file does not have to exist on disk.  If it does not exist, it is created for you.
 2. An empty string (`@""`).  An empty database is created at a temporary location.  This database is deleted with the `FMDatabase` connection is closed.
 3. `nil`.  An in-memory database is created.  This database will be destroyed with the `FMDatabase` connection is closed.

 For example, to create/open a database in your Mac OS X `tmp` folder:

    FMDatabase *db = [FMDatabase databaseWithPath:@"/tmp/tmp.db"];

 Or, in iOS, you might open a database in the app's `Documents` directory:

    NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *dbPath   = [docsPath stringByAppendingPathComponent:@"test.db"];
    FMDatabase *db     = [FMDatabase databaseWithPath:dbPath];

 (For more information on temporary and in-memory databases, read the sqlite documentation on the subject: [http://www.sqlite.org/inmemorydb.html](http://www.sqlite.org/inmemorydb.html))

 @param inPath Path of database file
 
 @return `FMDatabase` object if successful; `nil` if failure.

 */

- (instancetype)initWithPath:(NSString*)inPath;


///-----------------------------------
/// @name Opening and closing database
///-----------------------------------

/** Opening a new database connection
 
 The database is opened for reading and writing, and is created if it does not already exist.

 @return `YES` if successful, `NO` on error.

 @see [sqlite3_open()](http://sqlite.org/c3ref/open.html)
 @see openWithFlags:
 @see close
 */

- (BOOL)open;

/** Opening a new database connection with flags

 @param flags one of the following three values, optionally combined with the `SQLITE_OPEN_NOMUTEX`, `SQLITE_OPEN_FULLMUTEX`, `SQLITE_OPEN_SHAREDCACHE`, `SQLITE_OPEN_PRIVATECACHE`, and/or `SQLITE_OPEN_URI` flags:

 `SQLITE_OPEN_READONLY`

 The database is opened in read-only mode. If the database does not already exist, an error is returned.
 
 `SQLITE_OPEN_READWRITE`
 
 The database is opened for reading and writing if possible, or reading only if the file is write protected by the operating system. In either case the database must already exist, otherwise an error is returned.
 
 `SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE`
 
 The database is opened for reading and writing, and is created if it does not already exist. This is the behavior that is always used for `open` method.
 
 @return `YES` if successful, `NO` on error.

 @see [sqlite3_open_v2()](http://sqlite.org/c3ref/open.html)
 @see open
 @see close
 */

#if SQLITE_VERSION_NUMBER >= 3005000
- (BOOL)openWithFlags:(int)flags;
#endif

/** Closing a database connection
 
 @return `YES` if success, `NO` on error.
 
 @see [sqlite3_close()](http://sqlite.org/c3ref/close.html)
 @see open
 @see openWithFlags:
 */

- (BOOL)close;

/** Test to see if we have a good connection to the database.
 
 This will confirm whether:
 
 - is database open
 - if open, it will try a simple SELECT statement and confirm that it succeeds.

 @return `YES` if everything succeeds, `NO` on failure.
 */

- (BOOL)goodConnection;


///----------------------
/// @name Perform updates
///----------------------

/** Execute update statement
 
 This method employs [`sqlite3_bind`](http://sqlite.org/c3ref/bind_blob.html) for any optional value parameters. This  properly escapes any characters that need escape sequences (e.g. quotation marks), which eliminates simple SQL errors as well as protects against SQL injection attacks. This method natively handles `NSString`, `NSNumber`, `NSNull`, `NSDate`, and `NSData` objects. All other object types will be interpreted as text values using the object's `description` method.

 @param sql The SQL to be performed, with optional `?` placeholders.
 
 @param outErr A reference to the `NSError` pointer to be updated with an auto released `NSError` object if an error if an error occurs. If `nil`, no `NSError` object will be returned.
 
 @param ... Optional parameters to bind to `?` placeholders in the SQL statement. These should be Objective-C objects (e.g. `NSString`, `NSNumber`, etc.), not fundamental C data types (e.g. `int`, `char *`, etc.).

 @return `YES` upon success; `NO` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.

 @see lastError
 @see lastErrorCode
 @see lastErrorMessage
 @see [`sqlite3_bind`](http://sqlite.org/c3ref/bind_blob.html)
 */

- (BOOL)update:(NSString*)sql withErrorAndBindings:(NSError**)outErr, ...;

/** Execute update statement

 This method employs [`sqlite3_bind`](http://sqlite.org/c3ref/bind_blob.html) for any optional value parameters. This  properly escapes any characters that need escape sequences (e.g. quotation marks), which eliminates simple SQL errors as well as protects against SQL injection attacks. This method natively handles `NSString`, `NSNumber`, `NSNull`, `NSDate`, and `NSData` objects. All other object types will be interpreted as text values using the object's `description` method.
 
 @param sql The SQL to be performed, with optional `?` placeholders.

 @param ... Optional parameters to bind to `?` placeholders in the SQL statement. These should be Objective-C objects (e.g. `NSString`, `NSNumber`, etc.), not fundamental C data types (e.g. `int`, `char *`, etc.).

 @return `YES` upon success; `NO` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 
 @see lastError
 @see lastErrorCode
 @see lastErrorMessage
 @see [`sqlite3_bind`](http://sqlite.org/c3ref/bind_blob.html)
 */

- (BOOL)executeUpdate:(NSString*)sql, ...;

/** Execute update statement

 Any sort of SQL statement which is not a `SELECT` statement qualifies as an update.  This includes `CREATE`, `UPDATE`, `INSERT`, `ALTER`, `COMMIT`, `BEGIN`, `DETACH`, `DELETE`, `DROP`, `END`, `EXPLAIN`, `VACUUM`, and `REPLACE` statements (plus many more).  Basically, if your SQL statement does not begin with `SELECT`, it is an update statement.
 
 @param format The SQL to be performed, with `printf`-style escape sequences.

 @param ... Optional parameters to bind to use in conjunction with the `printf`-style escape sequences in the SQL statement.

 @return `YES` upon success; `NO` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.

 @see executeUpdate:
 @see lastError
 @see lastErrorCode
 @see lastErrorMessage
 
 @warning This should be used with great care. Generally, instead of this method, you should use `<executeUpdate:>` (with `?` placeholders in the SQL), which properly escapes quotation marks encountered inside the values (minimizing errors and protecting against SQL injection attack) and handles a wider variety of data types. See `<executeUpdate:>` for more information. 
 */

- (BOOL)executeUpdateWithFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(1,2);

/** Execute update statement

 Any sort of SQL statement which is not a `SELECT` statement qualifies as an update.  This includes `CREATE`, `UPDATE`, `INSERT`, `ALTER`, `COMMIT`, `BEGIN`, `DETACH`, `DELETE`, `DROP`, `END`, `EXPLAIN`, `VACUUM`, and `REPLACE` statements (plus many more).  Basically, if your SQL statement does not begin with `SELECT`, it is an update statement.

 @param sql The SQL to be performed, with optional `?` placeholders.

 @param arguments A `NSArray` of objects to be used when binding values to the `?` placeholders in the SQL statement.

 @return `YES` upon success; `NO` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.

 @see lastError
 @see lastErrorCode
 @see lastErrorMessage
 */

- (BOOL)executeUpdate:(NSString*)sql withArgumentsInArray:(NSArray *)arguments;

/** Execute update statement

 Any sort of SQL statement which is not a `SELECT` statement qualifies as an update.  This includes `CREATE`, `UPDATE`, `INSERT`, `ALTER`, `COMMIT`, `BEGIN`, `DETACH`, `DELETE`, `DROP`, `END`, `EXPLAIN`, `VACUUM`, and `REPLACE` statements (plus many more).  Basically, if your SQL statement does not begin with `SELECT`, it is an update statement.

 @param sql The SQL to be performed, with optional `?` placeholders.

 @param arguments A `NSDictionary` of objects keyed by column names that will be used when binding values to the `?` placeholders in the SQL statement.

 @return `YES` upon success; `NO` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.

 @see lastError
 @see lastErrorCode
 @see lastErrorMessage
*/

- (BOOL)executeUpdate:(NSString*)sql withParameterDictionary:(NSDictionary *)arguments;

/** Last insert rowid
 
 Each entry in an SQLite table has a unique 64-bit signed integer key called the "rowid". The rowid is always available as an undeclared column named `ROWID`, `OID`, or `_ROWID_` as long as those names are not also used by explicitly declared columns. If the table has a column of type `INTEGER PRIMARY KEY` then that column is another alias for the rowid.
 
 This routine returns the rowid of the most recent successful `INSERT` into the database from the database connection in the first argument. As of SQLite version 3.7.7, this routines records the last insert rowid of both ordinary tables and virtual tables. If no successful `INSERT`s have ever occurred on that database connection, zero is returned.
 
 @see [sqlite3_last_insert_rowid()](http://sqlite.org/c3ref/last_insert_rowid.html)

 */

- (sqlite_int64)lastInsertRowId;

/** The number of rows changed by prior SQL statement.
 
 This function returns the number of database rows that were changed or inserted or deleted by the most recently completed SQL statement on the database connection specified by the first parameter. Only changes that are directly specified by the INSERT, UPDATE, or DELETE statement are counted.
 
 @see [sqlite3_changes()](http://sqlite.org/c3ref/changes.html)
 
 */

- (int)changes;


///-------------------------
/// @name Retrieving results
///-------------------------

/** Execute select statement

 Executing queries returns an `<FMResultSet>` object if successful, and `nil` upon failure.  Like executing updates, there is a variant that accepts an `NSError **` parameter.  Otherwise you should use the `<lastErrorMessage>` and `<lastErrorMessage>` methods to determine why a query failed.
 
 In order to iterate through the results of your query, you use a `while()` loop.  You also need to "step" (via `<[FMResultSet next]>`) from one record to the other.
 
 This method employs [`sqlite3_bind`](http://sqlite.org/c3ref/bind_blob.html) for any optional value parameters. This  properly escapes any characters that need escape sequences (e.g. quotation marks), which eliminates simple SQL errors as well as protects against SQL injection attacks. This method natively handles `NSString`, `NSNumber`, `NSNull`, `NSDate`, and `NSData` objects. All other object types will be interpreted as text values using the object's `description` method.

 @param sql The SELECT statement to be performed, with optional `?` placeholders.

 @param ... Optional parameters to bind to `?` placeholders in the SQL statement. These should be Objective-C objects (e.g. `NSString`, `NSNumber`, etc.), not fundamental C data types (e.g. `int`, `char *`, etc.).

 @return A `<FMResultSet>` for the result set upon success; `nil` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 
 @see FMResultSet
 @see [`FMResultSet next`](<[FMResultSet next]>)
 @see [`sqlite3_bind`](http://sqlite.org/c3ref/bind_blob.html)
 */

- (FMResultSet *)executeQuery:(NSString*)sql, ...;

/** Execute select statement

 Executing queries returns an `<FMResultSet>` object if successful, and `nil` upon failure.  Like executing updates, there is a variant that accepts an `NSError **` parameter.  Otherwise you should use the `<lastErrorMessage>` and `<lastErrorMessage>` methods to determine why a query failed.
 
 In order to iterate through the results of your query, you use a `while()` loop.  You also need to "step" (via `<[FMResultSet next]>`) from one record to the other.
 
 @param format The SQL to be performed, with `printf`-style escape sequences.

 @param ... Optional parameters to bind to use in conjunction with the `printf`-style escape sequences in the SQL statement.

 @return A `<FMResultSet>` for the result set upon success; `nil` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.

 @see executeQuery:
 @see FMResultSet
 @see [`FMResultSet next`](<[FMResultSet next]>)

 @warning This should be used with great care. Generally, instead of this method, you should use `<executeQuery:>` (with `?` placeholders in the SQL), which properly escapes quotation marks encountered inside the values (minimizing errors and protecting against SQL injection attack) and handles a wider variety of data types. See `<executeQuery:>` for more information.

 */

- (FMResultSet *)executeQueryWithFormat:(NSString*)format, ... NS_FORMAT_FUNCTION(1,2);

/** Execute select statement

 Executing queries returns an `<FMResultSet>` object if successful, and `nil` upon failure.  Like executing updates, there is a variant that accepts an `NSError **` parameter.  Otherwise you should use the `<lastErrorMessage>` and `<lastErrorMessage>` methods to determine why a query failed.
 
 In order to iterate through the results of your query, you use a `while()` loop.  You also need to "step" (via `<[FMResultSet next]>`) from one record to the other.
 
 @param sql The SELECT statement to be performed, with optional `?` placeholders.

 @param arguments A `NSArray` of objects to be used when binding values to the `?` placeholders in the SQL statement.

 @return A `<FMResultSet>` for the result set upon success; `nil` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.

 @see FMResultSet
 @see [`FMResultSet next`](<[FMResultSet next]>)
 */

- (FMResultSet *)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray *)arguments;

/** Execute select statement

 Executing queries returns an `<FMResultSet>` object if successful, and `nil` upon failure.  Like executing updates, there is a variant that accepts an `NSError **` parameter.  Otherwise you should use the `<lastErrorMessage>` and `<lastErrorMessage>` methods to determine why a query failed.
 
 In order to iterate through the results of your query, you use a `while()` loop.  You also need to "step" (via `<[FMResultSet next]>`) from one record to the other.
 
 @param sql The SELECT statement to be performed, with optional `?` placeholders.

 @param arguments A `NSDictionary` of objects keyed by column names that will be used when binding values to the `?` placeholders in the SQL statement.

 @return A `<FMResultSet>` for the result set upon success; `nil` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.

 @see FMResultSet
 @see [`FMResultSet next`](<[FMResultSet next]>)
 */

- (FMResultSet *)executeQuery:(NSString *)sql withParameterDictionary:(NSDictionary *)arguments;

///-------------------
/// @name Transactions
///-------------------

/** Begin a transaction
 
 @return `YES` on success; `NO` on failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 
 @see commit
 @see rollback
 @see beginDeferredTransaction
 @see inTransaction
 */

- (BOOL)beginTransaction;

/** Begin a deferred transaction
 
 @return `YES` on success; `NO` on failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 
 @see commit
 @see rollback
 @see beginTransaction
 @see inTransaction
 */

- (BOOL)beginDeferredTransaction;

/** Commit a transaction

 Commit a transaction that was initiated with either `<beginTransaction>` or with `<beginDeferredTransaction>`.
 
 @return `YES` on success; `NO` on failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 
 @see beginTransaction
 @see beginDeferredTransaction
 @see rollback
 @see inTransaction
 */

- (BOOL)commit;

/** Rollback a transaction

 Rollback a transaction that was initiated with either `<beginTransaction>` or with `<beginDeferredTransaction>`.

 @return `YES` on success; `NO` on failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 
 @see beginTransaction
 @see beginDeferredTransaction
 @see commit
 @see inTransaction
 */

- (BOOL)rollback;

/** Identify whether currently in a transaction or not
 
 @return `YES` if currently within transaction; `NO` if not.
 
 @see beginTransaction
 @see beginDeferredTransaction
 @see commit
 @see rollback
 */

- (BOOL)inTransaction;


///----------------------------------------
/// @name Cached statements and result sets
///----------------------------------------

/** Clear cached statements */

- (void)clearCachedStatements;

/** Close all open result sets */

- (void)closeOpenResultSets;

/** Whether database has any open result sets
 
 @return `YES` if there are open result sets; `NO` if not.
 */

- (BOOL)hasOpenResultSets;

/** Return whether should cache statements or not
 
 @return `YES` if should cache statements; `NO` if not.
 */

- (BOOL)shouldCacheStatements;

/** Set whether should cache statements or not
 
 @param value `YES` if should cache statements; `NO` if not.
 */

- (void)setShouldCacheStatements:(BOOL)value;


///-------------------------
/// @name Encryption methods
///-------------------------

/** Set encryption key.
 
 @param key The key to be used.

 @return `YES` if success, `NO` on error.

 @see http://www.sqlite-encrypt.com/develop-guide.htm
 
 @warning You need to have purchased the sqlite encryption extensions for this method to work.
 */

- (BOOL)setKey:(NSString*)key;

/** Reset encryption key

 @param key The key to be used.

 @return `YES` if success, `NO` on error.

 @see http://www.sqlite-encrypt.com/develop-guide.htm

 @warning You need to have purchased the sqlite encryption extensions for this method to work.
 */

- (BOOL)rekey:(NSString*)key;

/** Set encryption key using `keyData`.
 
 @param keyData The `NSData` to be used.

 @return `YES` if success, `NO` on error.

 @see http://www.sqlite-encrypt.com/develop-guide.htm
 
 @warning You need to have purchased the sqlite encryption extensions for this method to work.
 */

- (BOOL)setKeyWithData:(NSData *)keyData;

/** Reset encryption key using `keyData`.

 @param keyData The `NSData` to be used.

 @return `YES` if success, `NO` on error.

 @see http://www.sqlite-encrypt.com/develop-guide.htm

 @warning You need to have purchased the sqlite encryption extensions for this method to work.
 */

- (BOOL)rekeyWithData:(NSData *)keyData;


///------------------------------
/// @name General inquiry methods
///------------------------------

/** The path of the database file
 
 @return path of database.
 
 */

- (NSString *)databasePath;

/** The underlying SQLite handle 
 
 @return The `sqlite3` pointer.
 
 */

- (sqlite3*)sqliteHandle;


///-----------------------------
/// @name Retrieving error codes
///-----------------------------

/** Last error message
 
 Returns the English-language text that describes the most recent failed SQLite API call associated with a database connection. If a prior API call failed but the most recent API call succeeded, this return value is undefined.

 @returns `NSString` of the last error message.
 
 @see [sqlite3_errmsg()](http://sqlite.org/c3ref/errcode.html)
 @see lastErrorCode
 @see lastError
 
 */

- (NSString*)lastErrorMessage;

/** Last error code
 
 Returns the numeric result code or extended result code for the most recent failed SQLite API call associated with a database connection. If a prior API call failed but the most recent API call succeeded, this return value is undefined.

 @returns Integer value of the last error code.

 @see [sqlite3_errcode()](http://sqlite.org/c3ref/errcode.html)
 @see lastErrorMessage
 @see lastError

 */

- (int)lastErrorCode;

/** Had error

 @return `YES` if there was an error, `NO` if no error.
 
 @see lastError
 @see lastErrorCode
 @see lastErrorMessage
 
 */

- (BOOL)hadError;

/** Last error

 @return `NSError` representing the last error.
 
 @see lastErrorCode
 @see lastErrorMessage
 
 */

- (NSError*)lastError;


#if SQLITE_VERSION_NUMBER >= 3007000

///------------------
/// @name Save points
///------------------

/** Start save point
 
 @param name Name of save point.
 
 @param outErr A `NSError` object to receive any error object (if any).
 
 @return `YES` on success; `NO` on failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 
 @see releaseSavePointWithName:error:
 @see rollbackToSavePointWithName:error:
 */

- (BOOL)startSavePointWithName:(NSString*)name error:(NSError**)outErr;

/** Release save point

 @param name Name of save point.
 
 @param outErr A `NSError` object to receive any error object (if any).
 
 @return `YES` on success; `NO` on failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.

 @see startSavePointWithName:error:
 @see rollbackToSavePointWithName:error:
 
 */

- (BOOL)releaseSavePointWithName:(NSString*)name error:(NSError**)outErr;

/** Roll back to save point

 @param name Name of save point.
 @param outErr A `NSError` object to receive any error object (if any).
 
 @return `YES` on success; `NO` on failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 
 @see startSavePointWithName:error:
 @see releaseSavePointWithName:error:
 
 */

- (BOOL)rollbackToSavePointWithName:(NSString*)name error:(NSError**)outErr;

/** Start save point

 @param block Block of code to perform from within save point.
 
 @return `YES` on success; `NO` on failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.

 @see startSavePointWithName:error:
 @see releaseSavePointWithName:error:
 @see rollbackToSavePointWithName:error:
 
 */

- (NSError*)inSavePoint:(void (^)(BOOL *rollback))block;

#endif

///----------------------------
/// @name SQLite library status
///----------------------------

/** Test to see if the library is threadsafe

 @return Zero if and only if SQLite was compiled with mutexing code omitted due to the SQLITE_THREADSAFE compile-time option being set to 0.

 @see [sqlite3_threadsafe()](http://sqlite.org/c3ref/threadsafe.html)
 */

+ (BOOL)isSQLiteThreadSafe;

/** Run-time library version numbers
 
 @see [sqlite3_libversion()](http://sqlite.org/c3ref/libversion.html)
 */

+ (NSString*)sqliteLibVersion;


///------------------------
/// @name Make SQL function
///------------------------

/** Adds SQL functions or aggregates or to redefine the behavior of existing SQL functions or aggregates.
 
 For example:
 
    [queue inDatabase:^(FMDatabase *adb) {

        [adb executeUpdate:@"create table ftest (foo text)"];
        [adb executeUpdate:@"insert into ftest values ('hello')"];
        [adb executeUpdate:@"insert into ftest values ('hi')"];
        [adb executeUpdate:@"insert into ftest values ('not h!')"];
        [adb executeUpdate:@"insert into ftest values ('definitely not h!')"];

        [adb makeFunctionNamed:@"StringStartsWithH" maximumArguments:1 withBlock:^(sqlite3_context *context, int aargc, sqlite3_value **aargv) {
            if (sqlite3_value_type(aargv[0]) == SQLITE_TEXT) {
                @autoreleasepool {
                    const char *c = (const char *)sqlite3_value_text(aargv[0]);
                    NSString *s = [NSString stringWithUTF8String:c];
                    sqlite3_result_int(context, [s hasPrefix:@"h"]);
                }
            }
            else {
                NSLog(@"Unknown formart for StringStartsWithH (%d) %s:%d", sqlite3_value_type(aargv[0]), __FUNCTION__, __LINE__);
                sqlite3_result_null(context);
            }
        }];

        int rowCount = 0;
        FMResultSet *ars = [adb executeQuery:@"select * from ftest where StringStartsWithH(foo)"];
        while ([ars next]) {
            rowCount++;
            NSLog(@"Does %@ start with 'h'?", [rs stringForColumnIndex:0]);
        }
        FMDBQuickCheck(rowCount == 2);
    }];

 @param name Name of function

 @param count Maximum number of parameters

 @param block The block of code for the function

 @see [sqlite3_create_function()](http://sqlite.org/c3ref/create_function.html)
 */

- (void)makeFunctionNamed:(NSString*)name maximumArguments:(int)count withBlock:(void (^)(sqlite3_context *context, int argc, sqlite3_value **argv))block;


///---------------------
/// @name Date formatter
///---------------------

/** Generate an `NSDateFormatter` that won't be broken by permutations of timezones or locales.
 
 Use this method to generate values to set the dateFormat property.
 
 Example:

    myDB.dateFormat = [FMDatabase storeableDateFormat:@"yyyy-MM-dd HH:mm:ss"];

 @param format A valid NSDateFormatter format string.
 
 @return A `NSDateFormatter` that can be used for converting dates to strings and vice versa.
 
 @see hasDateFormatter
 @see setDateFormat:
 @see dateFromString:
 @see stringFromDate:
 @see storeableDateFormat:

 @warning Note that `NSDateFormatter` is not thread-safe, so the formatter generated by this method should be assigned to only one FMDB instance and should not be used for other purposes.

 */

+ (NSDateFormatter *)storeableDateFormat:(NSString *)format;

/** Test whether the database has a date formatter assigned.
 
 @return `YES` if there is a date formatter; `NO` if not.
 
 @see hasDateFormatter
 @see setDateFormat:
 @see dateFromString:
 @see stringFromDate:
 @see storeableDateFormat:
 */

- (BOOL)hasDateFormatter;

/** Set to a date formatter to use string dates with sqlite instead of the default UNIX timestamps.
 
 @param format Set to nil to use UNIX timestamps. Defaults to nil. Should be set using a formatter generated using FMDatabase::storeableDateFormat.
 
 @see hasDateFormatter
 @see setDateFormat:
 @see dateFromString:
 @see stringFromDate:
 @see storeableDateFormat:
 
 @warning Note there is no direct getter for the `NSDateFormatter`, and you should not use the formatter you pass to FMDB for other purposes, as `NSDateFormatter` is not thread-safe.
 */

- (void)setDateFormat:(NSDateFormatter *)format;

/** Convert the supplied NSString to NSDate, using the current database formatter.
 
 @param s `NSString` to convert to `NSDate`.
 
 @return `nil` if no formatter is set.
 
 @see hasDateFormatter
 @see setDateFormat:
 @see dateFromString:
 @see stringFromDate:
 @see storeableDateFormat:
 */

- (NSDate *)dateFromString:(NSString *)s;

/** Convert the supplied NSDate to NSString, using the current database formatter.
 
 @param date `NSDate` of date to convert to `NSString`.

 @return `nil` if no formatter is set.
 
 @see hasDateFormatter
 @see setDateFormat:
 @see dateFromString:
 @see stringFromDate:
 @see storeableDateFormat:
 */

- (NSString *)stringFromDate:(NSDate *)date;

@end


/** Objective-C wrapper for `sqlite3_stmt`
 
 This is a wrapper for a SQLite `sqlite3_stmt`. Generally when using FMDB you will not need to interact directly with `FMStatement`, but rather with `<FMDatabase>` and `<FMResultSet>` only.
 
 ### See also
 
 - `<FMDatabase>`
 - `<FMResultSet>`
 - [`sqlite3_stmt`](http://www.sqlite.org/c3ref/stmt.html)
 */

@interface FMStatement : NSObject {
    sqlite3_stmt *_statement;
    NSString *_query;
    long _useCount;
}

///-----------------
/// @name Properties
///-----------------

/** Usage count */

@property (atomic, assign) long useCount;

/** SQL statement */

@property (atomic, retain) NSString *query;

/** SQLite sqlite3_stmt
 
 @see [`sqlite3_stmt`](http://www.sqlite.org/c3ref/stmt.html)
 */

@property (atomic, assign) sqlite3_stmt *statement;


///----------------------------
/// @name Closing and Resetting
///----------------------------

/** Close statement */

- (void)close;

/** Reset statement */

- (void)reset;

@end

