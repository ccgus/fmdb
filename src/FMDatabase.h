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


/** A SQLite ([http://sqlite.org/](http://sqlite.org/)) Objective-C wrapper.
 
 ### The FMDB Mailing List:
 [http://groups.google.com/group/fmdb](http://groups.google.com/group/fmdb)

 ### Read the SQLite FAQ:
 [http://www.sqlite.org/faq.html](http://www.sqlite.org/faq.html)

 Since FMDB is built on top of SQLite, you're going to want to read this page top to bottom at least once.  And while you're there, make sure to bookmark the SQLite Documentation page: [http://www.sqlite.org/docs.html](http://www.sqlite.org/docs.html)

 ### The FMDB Source Code:
 The source code is available on GitHub at [https://github.com/ccgus/fmdb](https://github.com/ccgus/fmdb)

 ### Automatic Reference Counting (ARC) or Manual Memory Management?
 You can use either style in your Cocoa project.  FMDB Will figure out which you are using at compile time and do the right thing.

 ### Usage
 There are three main classes in FMDB:

 1. `FMDatabase` - Represents a single SQLite database.  Used for executing SQL statements.
 2. `<FMResultSet>` - Represents the results of executing a query on an `FMDatabase`.
 3. `<FMDatabaseQueue>` - If you're wanting to perform queries and updates on multiple threads, you'll want to use this class.  It's described in the "Thread Safety" section below.

 #### Database Creation
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

 #### Opening

 Before you can interact with the database, it must be opened (see `<open>`).  Opening fails if there are insufficient resources or permissions to open and/or create the database.

    if (![db open]) {
        [db release];
        return;
    }

 #### Executing Updates

 Any sort of SQL statement which is not a `SELECT` statement qualifies as an update.  This includes `CREATE`, `UPDATE`, `INSERT`, `ALTER`, `COMMIT`, `BEGIN`, `DETACH`, `DELETE`, `DROP`, `END`, `EXPLAIN`, `VACUUM`, and `REPLACE` statements (plus many more).  Basically, if your SQL statement does not begin with `SELECT`, it is an update statement.

 Executing updates returns a single value, a `BOOL`.  A return value of `YES` means the update was successfully executed, and a return value of `NO` means that some error was encountered.  You may invoke the `<lastErrorMessage>` and `<lastErrorMessage>` methods to retrieve more information.

 #### Executing Queries

 A `SELECT` statement is a query and is executed via one of the `-executeQuery...` methods.

 Executing queries returns an `<FMResultSet>` object if successful, and `nil` upon failure.  Like executing updates, there is a variant that accepts an `NSError **` parameter.  Otherwise you should use the `<lastErrorMessage>` and `<lastErrorMessage>` methods to determine why a query failed.

 In order to iterate through the results of your query, you use a `while()` loop.  You also need to "step" (via `<[FMResultSet next]>`) from one record to the other.  With FMDB, the easiest way to do that is like this:

    FMResultSet *s = [db executeQuery:@"SELECT * FROM myTable"];
    while ([s next]) {
        //retrieve values for each record
    }

 You must always invoke `<FMResultSet next>` before attempting to access the values returned in a query, even if you're only expecting one:

    FMResultSet *s = [db executeQuery:@"SELECT COUNT(*) FROM myTable"];
    if ([s next]) {
        int totalCount = [s intForColumnIndex:0];
    }

 `<FMResultSet>` has many methods to retrieve data in an appropriate format:

 - `<[FMResultSet intForColumn:]>`
 - `<[FMResultSet longForColumn:]>`
 - `<[FMResultSet longLongIntForColumn:]>`
 - `<[FMResultSet boolForColumn:]>`
 - `<[FMResultSet doubleForColumn:]>`
 - `<[FMResultSet stringForColumn:]>`
 - `<[FMResultSet dateForColumn:]>`
 - `<[FMResultSet dataForColumn:]>`
 - `<[FMResultSet dataNoCopyForColumn:]>`
 - `<[FMResultSet UTF8StringForColumnName:]>`
 - `<[FMResultSet objectForColumnName:]>`

 Each of these methods also has a `{type}ForColumnIndex:` variant that is used to retrieve the data based on the position of the column in the results, as opposed to the column's name.

 Typically, there's no need to `<[FMResultSet close]>` an `<FMResultSet>` yourself, since that happens when either the result set is deallocated, or the parent database is closed.

 #### Closing

 When you have finished executing queries and updates on the database, you should `<close>` the `FMDatabase` connection so that SQLite will relinquish any resources it has acquired during the course of its operation.

    [db close];

 #### Transactions

 `FMDatabase` can begin and commit a transaction by invoking one of the appropriate methods or executing a begin/end transaction statement.

 #### Data Sanitization

 When providing a SQL statement to FMDB, you should not attempt to "sanitize" any values before insertion.  Instead, you should use the standard SQLite binding syntax:

    INSERT INTO myTable VALUES (?, ?, ?)

 The `?` character is recognized by SQLite as a placeholder for a value to be inserted.  The execution methods all accept a variable number of arguments (or a representation of those arguments, such as an `NSArray`, `NSDictionary`, or a `va_list`), which are properly escaped for you.

 Alternatively, you may use named parameters syntax:

    INSERT INTO myTable VALUES (:id, :name, :value)

 The parameters *must* start with a colon. SQLite itself supports other characters, but internally the Dictionary keys are prefixed with a colon, do **not** include the colon in your dictionary keys.

    NSDictionary *argsDict = [NSDictionary dictionaryWithObjectsAndKeys:@"My Name", @"name", nil];
    [db executeUpdate:@"INSERT INTO myTable (name) VALUES (:name)" withParameterDictionary:argsDict];

 Thus, you SHOULD NOT do this (or anything like this):

    [db executeUpdate:[NSString stringWithFormat:@"INSERT INTO myTable VALUES (%@)", @"this has \" lots of ' bizarre \" quotes '"]];

 Instead, you SHOULD do:

    [db executeUpdate:@"INSERT INTO myTable VALUES (?)", @"this has \" lots of ' bizarre \" quotes '"];

 All arguments provided to the `-executeUpdate:` method (or any of the variants that accept a `va_list` as a parameter) must be objects.  The following will not work (and will result in a crash):

    [db executeUpdate:@"INSERT INTO myTable VALUES (?)", 42];

 The proper way to insert a number is to box it in an `NSNumber` object:

    [db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:42]];

 Alternatively, you can use the `-execute*WithFormat:` variant to use `NSString`-style substitution:

    [db executeUpdateWithFormat:@"INSERT INTO myTable VALUES (%d)", 42];

 Internally, the `-execute*WithFormat:` methods are properly boxing things for you.  The following percent modifiers are recognized:  `%@`, `%c`, `%s`, `%d`, `%D`, `%i`, `%u`, `%U`, `%hi`, `%hu`, `%qi`, `%qu`, `%f`, `%g`, `%ld`, `%lu`, `%lld`, and `%llu`.  Using a modifier other than those will have unpredictable results.  If, for some reason, you need the `%` character to appear in your SQL statement, you should use `%%`.


 ### Using FMDatabaseQueue and Thread Safety.

 Using a single instance of `FMDatabase` from multiple threads at once is a bad idea.  It has always been OK to make a `FMDatabase` object *per thread*.  Just don't share a single instance across threads, and definitely not across multiple threads at the same time.  Bad things will eventually happen and you'll eventually get something to crash, or maybe get an exception, or maybe meteorites will fall out of the sky and hit your Mac Pro.  *This would suck*.

 Instead, use `<FMDatabaseQueue>`.  It's your friend and it's here to help.
 
 ### Making custom SQLite functions, based on blocks.

 You can do this!  For an example, see [`makeFunctionNamed`](makeFunctionNamed:maximumArguments:withBlock:).

 ---
 
 ### History

 The history and changes are availbe on its [GitHub page](https://github.com/ccgus/fmdb) and are summarized in the "CHANGES_AND_TODO_LIST.txt" file.

 ### Contributors

 The contributors to FMDB are contained in the "Contributors.txt" file.

 ### Reporting bugs

 Reduce your bug down to the smallest amount of code possible.  You want to make it super easy for the developers to see and reproduce your bug.  If it helps, pretend that the person who can fix your bug is active on shipping 3 major products, works on a handful of open source projects, has a newborn baby, and is generally very very busy.

 And we've even added a template function to `fmdb.m` (FMDBReportABugFunction) in the FMDB distribution to help you out:

 - Open up fmdb project in Xcode.
 - Open up main.m and modify the FMDBReportABugFunction to reproduce your bug.
 - Setup your table(s) in the code.
 - Make your query or update(s).
 - Add some assertions which demonstrate the bug.

 Then you can bring it up on the FMDB mailing list by showing your nice and compact FMDBReportABugFunction, or you can report the bug via the github FMDB bug reporter.

 **Optional:**

 Figure out where the bug is, fix it, and send a patch in or bring that up on the mailing list.  Make sure all the other tests run after your modifications.

 ### License
 
 The license for FMDB is contained in the "License.txt" file.
  
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

///---------------------------------------------------------------------------------------
/// @name Initialization
///---------------------------------------------------------------------------------------

/** An `FMDatabase` is created with a path to a SQLite database file.  This path can be one of these three:

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

+ (id)databaseWithPath:(NSString*)inPath;

/** An `FMDatabase` is created with a path to a SQLite database file.  This path can be one of these three:

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

- (id)initWithPath:(NSString*)inPath;


///---------------------------------------------------------------------------------------
/// @name Opening and closing database
///---------------------------------------------------------------------------------------

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

///---------------------------------------------------------------------------------------
/// @name Perform updates
///---------------------------------------------------------------------------------------

- (BOOL)update:(NSString*)sql withErrorAndBindings:(NSError**)outErr, ...;

/** Execute update statement

 @param sql The SQL to be performed, with optional `?` placeholders.

 @param ... Optional parameters to bind to `?` placeholders in the SQL statement.

 @return `YES` upon success; `NO` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 */

- (BOOL)executeUpdate:(NSString*)sql, ...;

/** Execute update statement

 @param format The SQL to be performed, with `printf`-style escape sequences.

 @param ... Optional parameters to bind to use in conjunction with the `printf`-style escape sequences in the SQL statement.

 @return `YES` upon success; `NO` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.

 @warning This should be used with great care. Generally, you should use `<executeUpdate:>` (with `?` placeholders) rather than this method.
 */

- (BOOL)executeUpdateWithFormat:(NSString *)format, ...;

/** Execute update statement

 @param sql The SQL to be performed, with optional `?` placeholders.

 @param arguments A `NSArray` of objects to be used when binding values to the `?` placeholders in the SQL statement.

 @return `YES` upon success; `NO` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 */

- (BOOL)executeUpdate:(NSString*)sql withArgumentsInArray:(NSArray *)arguments;

/** Execute update statement

 @param sql The SQL to be performed, with optional `?` placeholders.

 @param arguments A `NSDictionary` of objects keyed by column names that will be used when binding values to the `?` placeholders in the SQL statement.

 @return `YES` upon success; `NO` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 */

- (BOOL)executeUpdate:(NSString*)sql withParameterDictionary:(NSDictionary *)arguments;


///---------------------------------------------------------------------------------------
/// @name Retrieving results
///---------------------------------------------------------------------------------------

/** Execute select statement

 @param sql The SELECT statement to be performed, with optional `?` placeholders.

 @param ... Optional parameters to bind to `?` placeholders in the SQL statement.

 @return A `<FMResultSet>` for the result set upon success; `nil` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 */

- (FMResultSet *)executeQuery:(NSString*)sql, ...;

/** Execute select statement

 @param format The SQL to be performed, with `printf`-style escape sequences.

 @param ... Optional parameters to bind to use in conjunction with the `printf`-style escape sequences in the SQL statement.

 @return A `<FMResultSet>` for the result set upon success; `nil` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.

 @warning This should be used with great care. Generally, you should use `<executeQuery:>` (with `?` placeholders) rather than this method.
 */

- (FMResultSet *)executeQueryWithFormat:(NSString*)format, ...;

/** Execute select statement

 @param sql The SELECT statement to be performed, with optional `?` placeholders.

 @param arguments A `NSArray` of objects to be used when binding values to the `?` placeholders in the SQL statement.

 @return A `<FMResultSet>` for the result set upon success; `nil` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 */

- (FMResultSet *)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray *)arguments;

/** Execute select statement

 @param sql The SELECT statement to be performed, with optional `?` placeholders.

 @param arguments A `NSDictionary` of objects keyed by column names that will be used when binding values to the `?` placeholders in the SQL statement.

 @return A `<FMResultSet>` for the result set upon success; `nil` upon failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 */

- (FMResultSet *)executeQuery:(NSString *)sql withParameterDictionary:(NSDictionary *)arguments;

///---------------------------------------------------------------------------------------
/// @name Transactions
///---------------------------------------------------------------------------------------

/** Rollback a transaction

 @return `YES` on success; `NO` on failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.
 
 @see commit
 @see beginTransaction
 */

- (BOOL)rollback;

/** Commit a transaction

 @return `YES` on success; `NO` on failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.

 @see rollback
 @see beginTransaction
 */

- (BOOL)commit;

/** Begin a transaction

 @return `YES` on success; `NO` on failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.

 @see commit
 @see rollback
 */

- (BOOL)beginTransaction;

/** Begin a deferred transaction

 @return `YES` on success; `NO` on failure. If failed, you can call `<lastError>`, `<lastErrorCode>`, or `<lastErrorMessage>` for diagnostic information regarding the failure.

 @see commit
 @see rollback
 */

- (BOOL)beginDeferredTransaction;

/** Identify whether currently in a transaction or not

 @return `YES` on within transaction; `NO` if not.

 @see beginTransaction
 @see commit
 @see rollback
 */

- (BOOL)inTransaction;


///---------------------------------------------------------------------------------------
/// @name Cached statements and result sets
///---------------------------------------------------------------------------------------

/** Clear cached statements */

- (void)clearCachedStatements;

/** Close all open result sets */

- (void)closeOpenResultSets;

/** Whether database has any open result sets
 
 @return `YES` if there are open result sets; `NO` if not.
 */

- (BOOL)hasOpenResultSets;

///---------------------------------------------------------------------------------------
/// @name Encryption methods
///
/// You need to have purchased the sqlite encryption extensions for these to work.
///---------------------------------------------------------------------------------------

/** Set encryption key.
 
 @param key The key to be used.

 @return `YES` if success, `NO` on error.

 @see http://www.sqlite-encrypt.com/develop-guide.htm

 */

- (BOOL)setKey:(NSString*)key;

/** Reset encryption key

 @param key The key to be used.

 @return `YES` if success, `NO` on error.

 @see http://www.sqlite-encrypt.com/develop-guide.htm

 */

- (BOOL)rekey:(NSString*)key;

/** Set encryption key using `keyData`.
 
 @param keyData The `NSData` to be used.

 @return `YES` if success, `NO` on error.

 @see http://www.sqlite-encrypt.com/develop-guide.htm
 
 */

- (BOOL)setKeyWithData:(NSData *)keyData;

/** Reset encryption key using `keyData`.

 @param keyData The `NSData` to be used.

 @return `YES` if success, `NO` on error.

 @see http://www.sqlite-encrypt.com/develop-guide.htm

 */

- (BOOL)rekeyWithData:(NSData *)keyData;

///---------------------------------------------------------------------------------------
/// @name Database path
///---------------------------------------------------------------------------------------

/** The path of the database file. */

- (NSString *)databasePath;

///---------------------------------------------------------------------------------------
/// @name Retrieving error codes
///---------------------------------------------------------------------------------------

/** Last error message.
 
 Returns the English-language text that describes the most recent failed SQLite API call associated with a database connection. If a prior API call failed but the most recent API call succeeded, this return value is undefined.

 @returns `NSString` of the last error message.
 
 @see [sqlite3_errmsg()](http://sqlite.org/c3ref/errcode.html)
 @see lastErrorCode
 @see lastError
 
 */

- (NSString*)lastErrorMessage;

/** Last error code.
 
 Returns the numeric result code or extended result code for the most recent failed SQLite API call associated with a database connection. If a prior API call failed but the most recent API call succeeded, this return value is undefined.

 @returns Integer value of the last error code.

 @see [sqlite3_errcode()](http://sqlite.org/c3ref/errcode.html)
 @see lastErrorMessage
 @see lastError

 */

- (int)lastErrorCode;

/** Had error.

 @return `YES` if there was an error, `NO` if no error.
 
 @see lastError
 @see lastErrorCode
 @see lastErrorMessage
 */

- (BOOL)hadError;

/** Last error.

 @returns `NSError` representing the last error.
 
 @see lastErrorCode
 @see lastErrorMessage
 
 */

- (NSError*)lastError;


///---------------------------------------------------------------------------------------
/// @name Row ID of last insert
///---------------------------------------------------------------------------------------

/** Last insert rowid
 
 Each entry in an SQLite table has a unique 64-bit signed integer key called the "rowid". The rowid is always available as an undeclared column named ROWID, OID, or _ROWID_ as long as those names are not also used by explicitly declared columns. If the table has a column of type INTEGER PRIMARY KEY then that column is another alias for the rowid.

 This routine returns the rowid of the most recent successful INSERT into the database from the database connection in the first argument. As of SQLite version 3.7.7, this routines records the last insert rowid of both ordinary tables and virtual tables. If no successful INSERTs have ever occurred on that database connection, zero is returned.
 
 @see [sqlite3_last_insert_rowid()](http://sqlite.org/c3ref/last_insert_rowid.html)
 
 */

- (sqlite_int64)lastInsertRowId;


///---------------------------------------------------------------------------------------
/// @name SQLite handle
///---------------------------------------------------------------------------------------

- (sqlite3*)sqliteHandle;


///---------------------------------------------------------------------------------------
/// @name Statement caching
///---------------------------------------------------------------------------------------

- (BOOL)shouldCacheStatements;
- (void)setShouldCacheStatements:(BOOL)value;

///---------------------------------------------------------------------------------------
/// @name Save points
///---------------------------------------------------------------------------------------

#if SQLITE_VERSION_NUMBER >= 3007000
- (BOOL)startSavePointWithName:(NSString*)name error:(NSError**)outErr;
- (BOOL)releaseSavePointWithName:(NSString*)name error:(NSError**)outErr;
- (BOOL)rollbackToSavePointWithName:(NSString*)name error:(NSError**)outErr;
- (NSError*)inSavePoint:(void (^)(BOOL *rollback))block;
#endif

///---------------------------------------------------------------------------------------
/// @name SQLite library status
///---------------------------------------------------------------------------------------

/** Test to see if the library is threadsafe

 @return Zero if and only if SQLite was compiled with mutexing code omitted due to the SQLITE_THREADSAFE compile-time option being set to 0.

 @see [sqlite3_threadsafe()](http://sqlite.org/c3ref/threadsafe.html)
 */

+ (BOOL)isSQLiteThreadSafe;

/** Run-time library version numbers
 
 @see [sqlite3_libversion()](http://sqlite.org/c3ref/libversion.html)
 */

+ (NSString*)sqliteLibVersion;

///---------------------------------------------------------------------------------------
/// @name Number of rows modified
///---------------------------------------------------------------------------------------

/** This function returns the number of database rows that were changed or inserted or deleted by the most recently completed SQL statement on the database connection specified by the first parameter. Only changes that are directly specified by the INSERT, UPDATE, or DELETE statement are counted.

 @see [sqlite3_changes()](http://sqlite.org/c3ref/changes.html)
 */

- (int)changes;

///---------------------------------------------------------------------------------------
/// @name Make SQL function
///---------------------------------------------------------------------------------------

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

///---------------------------------------------------------------------------------------
/// @name Date formatter
///---------------------------------------------------------------------------------------

/** Generate an `NSDateFormatter` that won't be broken by permutations of timezones or locales.
 
 Use this method to generate values to set the dateFormat property.
 
 Example:

    myDB.dateFormat = [FMDatabase storeableDateFormat:@"yyyy-MM-dd HH:mm:ss"];

 @param format A valid NSDateFormatter format string.
 
 @return A `NSDateFormatter` that can be used for converting dates to strings and vice versa.
 
 @warning Note that `NSDateFormatter` is not thread-safe, so the formatter generated by this method should be assigned to only one FMDB instance and should not be used for other purposes.

 @see hasDateFormatter
 @see setDateFormat:
 @see dateFromString:
 @see stringFromDate:
 @see storeableDateFormat:
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
 
 @warning Note there is no direct getter for the `NSDateFormatter`, and you should not use the formatter you pass to FMDB for other purposes, as `NSDateFormatter` is not thread-safe.

 @see hasDateFormatter
 @see setDateFormat:
 @see dateFromString:
 @see stringFromDate:
 @see storeableDateFormat:
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

@interface FMStatement : NSObject {
    sqlite3_stmt *_statement;
    NSString *_query;
    long _useCount;
}

@property (atomic, assign) long useCount;
@property (atomic, retain) NSString *query;
@property (atomic, assign) sqlite3_stmt *statement;

- (void)close;
- (void)reset;

@end

