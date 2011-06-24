#import <Foundation/Foundation.h>
#import "sqlite3.h"
#import "FMResultSet.h"
#import "FMDatabasePool.h"

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
    
    FMDatabasePool      *_pool;
    NSInteger           _poolPopCount;
}


@property (assign) BOOL traceExecution;
@property (assign) BOOL checkedOut;
@property (assign) int busyRetryTimeout;
@property (assign) BOOL crashOnErrors;
@property (assign) BOOL logsErrors;
@property (retain) NSMutableDictionary *cachedStatements;
@property (assign) FMDatabasePool *pool;


+ (id)databaseWithPath:(NSString*)inPath;
- (id)initWithPath:(NSString*)inPath;

- (BOOL)open;
#if SQLITE_VERSION_NUMBER >= 3005000
- (BOOL)openWithFlags:(int)flags;
#endif
- (BOOL)close;
- (BOOL)goodConnection;
- (void)clearCachedStatements;
- (void)closeOpenResultSets;

// encryption methods.  You need to have purchased the sqlite encryption extensions for these to work.
- (BOOL)setKey:(NSString*)key;
- (BOOL)rekey:(NSString*)key;

- (NSString *)databasePath;

- (NSString*)lastErrorMessage;

- (int)lastErrorCode;
- (BOOL)hadError;
- (NSError*)lastError;

- (sqlite_int64)lastInsertRowId;

- (sqlite3*)sqliteHandle;

- (BOOL)update:(NSString*)sql error:(NSError**)outErr bind:(id)bindArgs, ...;
- (BOOL)executeUpdate:(NSString*)sql, ...;
- (BOOL)executeUpdateWithFormat:(NSString *)format, ...;
- (BOOL)executeUpdate:(NSString*)sql withArgumentsInArray:(NSArray *)arguments;
- (BOOL)executeUpdate:(NSString*)sql error:(NSError**)outErr withArgumentsInArray:(NSArray*)arrayArgs orVAList:(va_list)args; // you shouldn't ever need to call this.  use the previous two instead.

- (FMResultSet *)executeQuery:(NSString*)sql, ...;
- (FMResultSet *)executeQueryWithFormat:(NSString*)format, ...;
- (FMResultSet *)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray *)arguments;
- (FMResultSet *)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray*)arrayArgs orVAList:(va_list)args; // you shouldn't ever need to call this.  use the previous two instead.

- (BOOL)rollback;
- (BOOL)commit;
- (BOOL)beginTransaction;
- (BOOL)beginDeferredTransaction;
- (BOOL)inTransaction;
- (BOOL)shouldCacheStatements;
- (void)setShouldCacheStatements:(BOOL)value;

#if SQLITE_VERSION_NUMBER >= 3007000
- (BOOL)startSavePointWithName:(NSString*)name error:(NSError**)outErr;
- (BOOL)releaseSavePointWithName:(NSString*)name error:(NSError**)outErr;
- (BOOL)rollbackToSavePointWithName:(NSString*)name error:(NSError**)outErr;
- (NSError*)inSavePoint:(void (^)(BOOL *rollback))block;
#endif

+ (BOOL)isSQLiteThreadSafe;
+ (NSString*)sqliteLibVersion;

- (int)changes;

- (FMDatabase*)popFromPool;
- (void)pushToPool;


@end

@interface FMStatement : NSObject {
    sqlite3_stmt *statement;
    NSString *query;
    long useCount;
}

@property (assign) long useCount;
@property (retain) NSString *query;
@property (assign) sqlite3_stmt *statement;

- (void)close;
- (void)reset;

@end

