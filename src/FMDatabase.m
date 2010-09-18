#import "FMDatabase.h"
#import "unistd.h"

@implementation FMDatabase

+ (id)databaseWithPath:(NSString*)aPath {
    return [[[self alloc] initWithPath:aPath] autorelease];
}

- (id)initWithPath:(NSString*)aPath {
    self = [super init];
	
    if (self) {
        databasePath        = [aPath copy];
        db                  = 0x00;
        logsErrors          = 0x00;
        crashOnErrors       = 0x00;
        busyRetryTimeout    = 0x00;
    }
	
	return self;
}

- (void)dealloc {
	[self close];
    
    [cachedStatements release];
    [databasePath release];
	
    [super dealloc];
}

+ (NSString*)sqliteLibVersion {
    return [NSString stringWithFormat:@"%s", sqlite3_libversion()];
}

- (NSString *)databasePath {
    return databasePath;
}

- (sqlite3*)sqliteHandle {
    return db;
}

- (BOOL)open {
	int err = sqlite3_open([databasePath fileSystemRepresentation], &db );
	if(err != SQLITE_OK) {
        NSLog(@"error opening!: %d", err);
		return NO;
	}
	
	return YES;
}

#if SQLITE_VERSION_NUMBER >= 3005000
- (BOOL)openWithFlags:(int)flags {
    int err = sqlite3_open_v2([databasePath fileSystemRepresentation], &db, flags, NULL /* Name of VFS module to use */);
	if(err != SQLITE_OK) {
		NSLog(@"error opening!: %d", err);
		return NO;
	}
	return YES;
}
#endif


- (BOOL)close {
    
    [self clearCachedStatements];
    
	if (!db) {
        return YES;
    }
    
    int  rc;
    BOOL retry;
    int numberOfRetries = 0;
    do {
        retry   = NO;
        rc      = sqlite3_close(db);
        if (SQLITE_BUSY == rc) {
            retry = YES;
            usleep(20);
            if (busyRetryTimeout && (numberOfRetries++ > busyRetryTimeout)) {
                NSLog(@"%s:%d", __FUNCTION__, __LINE__);
                NSLog(@"Database busy, unable to close");
                return NO;
            }
        }
        else if (SQLITE_OK != rc) {
            NSLog(@"error closing!: %d", rc);
        }
    }
    while (retry);
    
	db = nil;
    return YES;
}

- (void)clearCachedStatements {
    
    NSEnumerator *e = [cachedStatements objectEnumerator];
    FMStatement *cachedStmt;

    while ((cachedStmt = [e nextObject])) {
    	[cachedStmt close];
    }
    
    [cachedStatements removeAllObjects];
}

- (FMStatement*)cachedStatementForQuery:(NSString*)query {
    return [cachedStatements objectForKey:query];
}

- (void)setCachedStatement:(FMStatement*)statement forQuery:(NSString*)query {
    //NSLog(@"setting query: %@", query);
    query = [query copy]; // in case we got handed in a mutable string...
    [statement setQuery:query];
    [cachedStatements setObject:statement forKey:query];
    [query release];
}


- (BOOL)rekey:(NSString*)key {
#ifdef SQLITE_HAS_CODEC
    if (!key) {
        return NO;
    }
    
    int rc = sqlite3_rekey(db, [key UTF8String], strlen([key UTF8String]));
    
    if (rc != SQLITE_OK) {
        NSLog(@"error on rekey: %d", rc);
        NSLog(@"%@", [self lastErrorMessage]);
    }
    
    return (rc == SQLITE_OK);
#else
    return NO;
#endif
}

- (BOOL)setKey:(NSString*)key {
#ifdef SQLITE_HAS_CODEC
    if (!key) {
        return NO;
    }
    
    int rc = sqlite3_key(db, [key UTF8String], strlen([key UTF8String]));
    
    return (rc == SQLITE_OK);
#else
    return NO;
#endif
}

- (BOOL)goodConnection {
    
    if (!db) {
        return NO;
    }
    
    FMResultSet *rs = [self executeQuery:@"select name from sqlite_master where type='table'"];
    
    if (rs) {
        [rs close];
        return YES;
    }
    
    return NO;
}

- (void)compainAboutInUse {
    NSLog(@"The FMDatabase %@ is currently in use.", self);
    
    if (crashOnErrors) {
        NSAssert1(false, @"The FMDatabase %@ is currently in use.", self);
    }
}

- (NSString*)lastErrorMessage {
    return [NSString stringWithUTF8String:sqlite3_errmsg(db)];
}

- (BOOL)hadError {
    int lastErrCode = [self lastErrorCode];
    
    return (lastErrCode > SQLITE_OK && lastErrCode < SQLITE_ROW);
}

- (int)lastErrorCode {
    return sqlite3_errcode(db);
}

- (sqlite_int64)lastInsertRowId {
    
    if (inUse) {
        [self compainAboutInUse];
        return NO;
    }
    [self setInUse:YES];
    
    sqlite_int64 ret = sqlite3_last_insert_rowid(db);
    
    [self setInUse:NO];
    
    return ret;
}

- (void)bindObject:(id)obj toColumn:(int)idx inStatement:(sqlite3_stmt*)pStmt; {
    
    if ((!obj) || ((NSNull *)obj == [NSNull null])) {
        sqlite3_bind_null(pStmt, idx);
    }
    
    // FIXME - someday check the return codes on these binds.
    else if ([obj isKindOfClass:[NSData class]]) {
        sqlite3_bind_blob(pStmt, idx, [obj bytes], (int)[obj length], SQLITE_STATIC);
    }
    else if ([obj isKindOfClass:[NSDate class]]) {
        sqlite3_bind_double(pStmt, idx, [obj timeIntervalSince1970]);
    }
    else if ([obj isKindOfClass:[NSNumber class]]) {
        
        if (strcmp([obj objCType], @encode(BOOL)) == 0) {
            sqlite3_bind_int(pStmt, idx, ([obj boolValue] ? 1 : 0));
        }
        else if (strcmp([obj objCType], @encode(int)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longValue]);
        }
        else if (strcmp([obj objCType], @encode(long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longValue]);
        }
        else if (strcmp([obj objCType], @encode(long long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longLongValue]);
        }
        else if (strcmp([obj objCType], @encode(float)) == 0) {
            sqlite3_bind_double(pStmt, idx, [obj floatValue]);
        }
        else if (strcmp([obj objCType], @encode(double)) == 0) {
            sqlite3_bind_double(pStmt, idx, [obj doubleValue]);
        }
        else {
            sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
        }
    }
    else {
        sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
    }
}

- (FMResultSet *)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray*)arrayArgs orVAList:(va_list)args {
    
    if (inUse) {
        [self compainAboutInUse];
        return nil;
    }
    
    [self setInUse:YES];
    
    FMResultSet *rs = nil;
    
    int rc                  = 0x00;;
    sqlite3_stmt *pStmt     = 0x00;;
    FMStatement *statement  = 0x00;
    
    if (traceExecution && sql) {
        NSLog(@"%@ executeQuery: %@", self, sql);
    }
    
    if (shouldCacheStatements) {
        statement = [self cachedStatementForQuery:sql];
        pStmt = statement ? [statement statement] : 0x00;
    }
    
    int numberOfRetries = 0;
    BOOL retry          = NO;
    
    if (!pStmt) {
        do {
            retry   = NO;
            rc      = sqlite3_prepare_v2(db, [sql UTF8String], -1, &pStmt, 0);
            
            if (SQLITE_BUSY == rc) {
                retry = YES;
                usleep(20);
                
                if (busyRetryTimeout && (numberOfRetries++ > busyRetryTimeout)) {
                    NSLog(@"%s:%d Database busy (%@)", __FUNCTION__, __LINE__, [self databasePath]);
                    NSLog(@"Database busy");
                    sqlite3_finalize(pStmt);
                    [self setInUse:NO];
                    return nil;
                }
            }
            else if (SQLITE_OK != rc) {
                
                
                if (logsErrors) {
                    NSLog(@"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]);
                    NSLog(@"DB Query: %@", sql);
                    if (crashOnErrors) {
//#if defined(__BIG_ENDIAN__) && !TARGET_IPHONE_SIMULATOR
//                        asm{ trap };
//#endif
                        NSAssert2(false, @"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]);
                    }
                }
                
                sqlite3_finalize(pStmt);
                
                [self setInUse:NO];
                return nil;
            }
        }
        while (retry);
    }
    
    id obj;
    int idx = 0;
    int queryCount = sqlite3_bind_parameter_count(pStmt); // pointed out by Dominic Yu (thanks!)
    
    while (idx < queryCount) {
        
        if (arrayArgs) {
            obj = [arrayArgs objectAtIndex:idx];
        }
        else {
            obj = va_arg(args, id);
        }
        
        if (traceExecution) {
            NSLog(@"obj: %@", obj);
        }
        
        idx++;
        
        [self bindObject:obj toColumn:idx inStatement:pStmt];
    }
    
    if (idx != queryCount) {
        NSLog(@"Error: the bind count is not correct for the # of variables (executeQuery)");
        sqlite3_finalize(pStmt);
        [self setInUse:NO];
        return nil;
    }
    
    [statement retain]; // to balance the release below
    
    if (!statement) {
        statement = [[FMStatement alloc] init];
        [statement setStatement:pStmt];
        
        if (shouldCacheStatements) {
            [self setCachedStatement:statement forQuery:sql];
        }
    }
    
    // the statement gets close in rs's dealloc or [rs close];
    rs = [FMResultSet resultSetWithStatement:statement usingParentDatabase:self];
    [rs setQuery:sql];
    
    statement.useCount = statement.useCount + 1;
    
    [statement release];    
    
    [self setInUse:NO];
    
    return rs;
}

- (FMResultSet *)executeQuery:(NSString*)sql, ... {
    va_list args;
    va_start(args, sql);
    
    id result = [self executeQuery:sql withArgumentsInArray:nil orVAList:args];
    
    va_end(args);
    return result;
}

- (FMResultSet *)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray *)arguments {
    return [self executeQuery:sql withArgumentsInArray:arguments orVAList:nil];
}

- (BOOL)executeUpdate:(NSString*)sql withArgumentsInArray:(NSArray*)arrayArgs orVAList:(va_list)args {
    
    if (inUse) {
        [self compainAboutInUse];
        return NO;
    }
    
    [self setInUse:YES];
    
    int rc                   = 0x00;
    sqlite3_stmt *pStmt      = 0x00;
    FMStatement *cachedStmt = 0x00;
    
    if (traceExecution && sql) {
        NSLog(@"%@ executeUpdate: %@", self, sql);
    }
    
    if (shouldCacheStatements) {
        cachedStmt = [self cachedStatementForQuery:sql];
        pStmt = cachedStmt ? [cachedStmt statement] : 0x00;
    }
    
    int numberOfRetries = 0;
    BOOL retry          = NO;
    
    if (!pStmt) {
        
        do {
            retry   = NO;
            rc      = sqlite3_prepare_v2(db, [sql UTF8String], -1, &pStmt, 0);
            if (SQLITE_BUSY == rc) {
                retry = YES;
                usleep(20);
                
                if (busyRetryTimeout && (numberOfRetries++ > busyRetryTimeout)) {
                    NSLog(@"%s:%d Database busy (%@)", __FUNCTION__, __LINE__, [self databasePath]);
                    NSLog(@"Database busy");
                    sqlite3_finalize(pStmt);
                    [self setInUse:NO];
                    return NO;
                }
            }
            else if (SQLITE_OK != rc) {
                
                
                if (logsErrors) {
                    NSLog(@"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]);
                    NSLog(@"DB Query: %@", sql);
                    if (crashOnErrors) {
//#if defined(__BIG_ENDIAN__) && !TARGET_IPHONE_SIMULATOR
//                        asm{ trap };
//#endif
                        NSAssert2(false, @"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]);
                    }
                }
                
                sqlite3_finalize(pStmt);
                [self setInUse:NO];
                
                return NO;
            }
        }
        while (retry);
    }
    
    
    id obj;
    int idx = 0;
    int queryCount = sqlite3_bind_parameter_count(pStmt);
    
    while (idx < queryCount) {
        
        if (arrayArgs) {
            obj = [arrayArgs objectAtIndex:idx];
        }
        else {
            obj = va_arg(args, id);
        }
        
        
        if (traceExecution) {
            NSLog(@"obj: %@", obj);
        }
        
        idx++;
        
        [self bindObject:obj toColumn:idx inStatement:pStmt];
    }
    
    if (idx != queryCount) {
        NSLog(@"Error: the bind count is not correct for the # of variables (%@) (executeUpdate)", sql);
        sqlite3_finalize(pStmt);
        [self setInUse:NO];
        return NO;
    }
    
    /* Call sqlite3_step() to run the virtual machine. Since the SQL being
     ** executed is not a SELECT statement, we assume no data will be returned.
     */
    numberOfRetries = 0;
    do {
        rc      = sqlite3_step(pStmt);
        retry   = NO;
        
        if (SQLITE_BUSY == rc) {
            // this will happen if the db is locked, like if we are doing an update or insert.
            // in that case, retry the step... and maybe wait just 10 milliseconds.
            retry = YES;
            usleep(20);
            
            if (busyRetryTimeout && (numberOfRetries++ > busyRetryTimeout)) {
                NSLog(@"%s:%d Database busy (%@)", __FUNCTION__, __LINE__, [self databasePath]);
                NSLog(@"Database busy");
                retry = NO;
            }
        }
        else if (SQLITE_DONE == rc || SQLITE_ROW == rc) {
            // all is well, let's return.
        }
        else if (SQLITE_ERROR == rc) {
            NSLog(@"Error calling sqlite3_step (%d: %s) SQLITE_ERROR", rc, sqlite3_errmsg(db));
            NSLog(@"DB Query: %@", sql);
        }
        else if (SQLITE_MISUSE == rc) {
            // uh oh.
            NSLog(@"Error calling sqlite3_step (%d: %s) SQLITE_MISUSE", rc, sqlite3_errmsg(db));
            NSLog(@"DB Query: %@", sql);
        }
        else {
            // wtf?
            NSLog(@"Unknown error calling sqlite3_step (%d: %s) eu", rc, sqlite3_errmsg(db));
            NSLog(@"DB Query: %@", sql);
        }
        
    } while (retry);
    
    assert( rc!=SQLITE_ROW );
    
    
    if (shouldCacheStatements && !cachedStmt) {
        cachedStmt = [[FMStatement alloc] init];
        
        [cachedStmt setStatement:pStmt];
        
        [self setCachedStatement:cachedStmt forQuery:sql];
        
        [cachedStmt release];
    }
    
    if (cachedStmt) {
        cachedStmt.useCount = cachedStmt.useCount + 1;
        rc = sqlite3_reset(pStmt);
    }
    else {
        /* Finalize the virtual machine. This releases all memory and other
         ** resources allocated by the sqlite3_prepare() call above.
         */
        rc = sqlite3_finalize(pStmt);
    }
    
    [self setInUse:NO];
    
    return (rc == SQLITE_OK);
}


- (BOOL)executeUpdate:(NSString*)sql, ... {
    va_list args;
    va_start(args, sql);
    
    BOOL result = [self executeUpdate:sql withArgumentsInArray:nil orVAList:args];
    
    va_end(args);
    return result;
}



- (BOOL)executeUpdate:(NSString*)sql withArgumentsInArray:(NSArray *)arguments {
    return [self executeUpdate:sql withArgumentsInArray:arguments orVAList:nil];
}

/*
- (id) executeUpdate:(NSString *)sql arguments:(va_list)args {
    
}
*/

- (BOOL)rollback {
    BOOL b = [self executeUpdate:@"ROLLBACK TRANSACTION;"];
    if (b) {
        inTransaction = NO;
    }
    return b;
}

- (BOOL)commit {
    BOOL b =  [self executeUpdate:@"COMMIT TRANSACTION;"];
    if (b) {
        inTransaction = NO;
    }
    return b;
}

- (BOOL)beginDeferredTransaction {
    BOOL b =  [self executeUpdate:@"BEGIN DEFERRED TRANSACTION;"];
    if (b) {
        inTransaction = YES;
    }
    return b;
}

- (BOOL)beginTransaction {
    BOOL b =  [self executeUpdate:@"BEGIN EXCLUSIVE TRANSACTION;"];
    if (b) {
        inTransaction = YES;
    }
    return b;
}

- (BOOL)logsErrors {
    return logsErrors;
}
- (void)setLogsErrors:(BOOL)flag {
    logsErrors = flag;
}

- (BOOL)crashOnErrors {
    return crashOnErrors;
}
- (void)setCrashOnErrors:(BOOL)flag {
    crashOnErrors = flag;
}

- (BOOL)inUse {
    return inUse || inTransaction;
}

- (void)setInUse:(BOOL)b {
    inUse = b;
}

- (BOOL)inTransaction {
    return inTransaction;
}
- (void)setInTransaction:(BOOL)flag {
    inTransaction = flag;
}

- (BOOL)traceExecution {
    return traceExecution;
}
- (void)setTraceExecution:(BOOL)flag {
    traceExecution = flag;
}

- (BOOL)checkedOut {
    return checkedOut;
}
- (void)setCheckedOut:(BOOL)flag {
    checkedOut = flag;
}


- (int)busyRetryTimeout {
    return busyRetryTimeout;
}
- (void)setBusyRetryTimeout:(int)newBusyRetryTimeout {
    busyRetryTimeout = newBusyRetryTimeout;
}


- (BOOL)shouldCacheStatements {
    return shouldCacheStatements;
}

- (void)setShouldCacheStatements:(BOOL)value {
    
    shouldCacheStatements = value;
    
    if (shouldCacheStatements && !cachedStatements) {
        [self setCachedStatements:[NSMutableDictionary dictionary]];
    }
    
    if (!shouldCacheStatements) {
        [self setCachedStatements:nil];
    }
}

- (NSMutableDictionary *) cachedStatements {
    return cachedStatements;
}

- (void)setCachedStatements:(NSMutableDictionary *)value {
    if (cachedStatements != value) {
        [cachedStatements release];
        cachedStatements = [value retain];
    }
}


- (int)changes {
    return(sqlite3_changes(db));
}

@end



@implementation FMStatement

- (void)dealloc {
	[self close];
    [query release];
	[super dealloc];
}


- (void)close {
    if (statement) {
        sqlite3_finalize(statement);
        statement = 0x00;
    }
}

- (void)reset {
    if (statement) {
        sqlite3_reset(statement);
    }
}

- (sqlite3_stmt *)statement {
    return statement;
}

- (void)setStatement:(sqlite3_stmt *)value {
    statement = value;
}

- (NSString *)query {
    return query;
}

- (void)setQuery:(NSString *)value {
    if (query != value) {
        [query release];
        query = [value retain];
    }
}

- (long)useCount {
    return useCount;
}

- (void)setUseCount:(long)value {
    if (useCount != value) {
        useCount = value;
    }
}

- (NSString*)description {
    return [NSString stringWithFormat:@"%@ %d hit(s) for query %@", [super description], useCount, query];
}


@end

