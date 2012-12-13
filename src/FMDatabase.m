#import "FMDatabase.h"
#import "unistd.h"
#import <objc/runtime.h>

@interface FMDatabase ()

- (FMResultSet *)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray*)arrayArgs orDictionary:(NSDictionary *)dictionaryArgs orVAList:(va_list)args;
- (BOOL)executeUpdate:(NSString*)sql error:(NSError**)outErr withArgumentsInArray:(NSArray*)arrayArgs orDictionary:(NSDictionary *)dictionaryArgs orVAList:(va_list)args;
@end

@implementation FMDatabase
@synthesize cachedStatements=_cachedStatements;
@synthesize logsErrors=_logsErrors;
@synthesize crashOnErrors=_crashOnErrors;
@synthesize busyRetryTimeout=_busyRetryTimeout;
@synthesize checkedOut=_checkedOut;
@synthesize traceExecution=_traceExecution;

+ (id)databaseWithPath:(NSString*)aPath {
    return FMDBReturnAutoreleased([[self alloc] initWithPath:aPath]);
}

+ (NSString*)sqliteLibVersion {
    return [NSString stringWithFormat:@"%s", sqlite3_libversion()];
}

+ (BOOL)isSQLiteThreadSafe {
    // make sure to read the sqlite headers on this guy!
    return sqlite3_threadsafe() != 0;
}

- (id)initWithPath:(NSString*)aPath {
    
    assert(sqlite3_threadsafe()); // whoa there big boy- gotta make sure sqlite it happy with what we're going to do.
    
    self = [super init];
    
    if (self) {
        _databasePath       = [aPath copy];
        _openResultSets     = [[NSMutableSet alloc] init];
        _db                 = 0x00;
        _logsErrors         = 0x00;
        _crashOnErrors      = 0x00;
        _busyRetryTimeout   = 0x00;
    }
    
    return self;
}

- (void)finalize {
    [self close];
    [super finalize];
}

- (void)dealloc {
    [self close];
    FMDBRelease(_openResultSets);
    FMDBRelease(_cachedStatements);
    FMDBRelease(_databasePath);
    FMDBRelease(_openFunctions);
    
#if ! __has_feature(objc_arc)
    [super dealloc];
#endif
}

- (NSString *)databasePath {
    return _databasePath;
}

- (sqlite3*)sqliteHandle {
    return _db;
}

- (BOOL)open {
    if (_db) {
        return YES;
    }
    
    int err = sqlite3_open((_databasePath ? [_databasePath fileSystemRepresentation] : ":memory:"), &_db );
    if(err != SQLITE_OK) {
        NSLog(@"error opening!: %d", err);
        return NO;
    }
    
    return YES;
}

#if SQLITE_VERSION_NUMBER >= 3005000
- (BOOL)openWithFlags:(int)flags {
    int err = sqlite3_open_v2((_databasePath ? [_databasePath fileSystemRepresentation] : ":memory:"), &_db, flags, NULL /* Name of VFS module to use */);
    if(err != SQLITE_OK) {
        NSLog(@"error opening!: %d", err);
        return NO;
    }
    return YES;
}
#endif


- (BOOL)close {
    
    [self clearCachedStatements];
    [self closeOpenResultSets];
    
    if (!_db) {
        return YES;
    }
    
    int  rc;
    BOOL retry;
    int numberOfRetries = 0;
    BOOL triedFinalizingOpenStatements = NO;
    
    do {
        retry   = NO;
        rc      = sqlite3_close(_db);
        
        if (SQLITE_BUSY == rc || SQLITE_LOCKED == rc) {
            
            retry = YES;
            usleep(20);
            
            if (_busyRetryTimeout && (numberOfRetries++ > _busyRetryTimeout)) {
                NSLog(@"%s:%d", __FUNCTION__, __LINE__);
                NSLog(@"Database busy, unable to close");
                return NO;
            }
            
            if (!triedFinalizingOpenStatements) {
                triedFinalizingOpenStatements = YES;
                sqlite3_stmt *pStmt;
                while ((pStmt = sqlite3_next_stmt(_db, 0x00)) !=0) {
                    NSLog(@"Closing leaked statement");
                    sqlite3_finalize(pStmt);
                }
            }
        }
        else if (SQLITE_OK != rc) {
            NSLog(@"error closing!: %d", rc);
        }
    }
    while (retry);
    
    _db = nil;
    return YES;
}

- (void)clearCachedStatements {
    
    for (FMStatement *cachedStmt in [_cachedStatements objectEnumerator]) {
        [cachedStmt close];
    }
    
    [_cachedStatements removeAllObjects];
}

- (BOOL)hasOpenResultSets {
    return [_openResultSets count] > 0;
}

- (void)closeOpenResultSets {
    
    //Copy the set so we don't get mutation errors
    NSMutableSet *openSetCopy = FMDBReturnAutoreleased([_openResultSets copy]);
    for (NSValue *rsInWrappedInATastyValueMeal in openSetCopy) {
        FMResultSet *rs = (FMResultSet *)[rsInWrappedInATastyValueMeal pointerValue];
        
        [rs setParentDB:nil];
        [rs close];
        
        [_openResultSets removeObject:rsInWrappedInATastyValueMeal];
    }
}

- (void)resultSetDidClose:(FMResultSet *)resultSet {
    NSValue *setValue = [NSValue valueWithNonretainedObject:resultSet];
    
    [_openResultSets removeObject:setValue];
}

- (FMStatement*)cachedStatementForQuery:(NSString*)query {
    return [_cachedStatements objectForKey:query];
}

- (void)setCachedStatement:(FMStatement*)statement forQuery:(NSString*)query {
    
    query = [query copy]; // in case we got handed in a mutable string...
    
    [statement setQuery:query];
    
    [_cachedStatements setObject:statement forKey:query];
    
    FMDBRelease(query);
}


- (BOOL)rekey:(NSString*)key {
#ifdef SQLITE_HAS_CODEC
    if (!key) {
        return NO;
    }
    
    int rc = sqlite3_rekey(_db, [key UTF8String], (int)strlen([key UTF8String]));
    
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
    
    int rc = sqlite3_key(_db, [key UTF8String], (int)strlen([key UTF8String]));
    
    return (rc == SQLITE_OK);
#else
    return NO;
#endif
}

- (BOOL)goodConnection {
    
    if (!_db) {
        return NO;
    }
    
    FMResultSet *rs = [self executeQuery:@"select name from sqlite_master where type='table'"];
    
    if (rs) {
        [rs close];
        return YES;
    }
    
    return NO;
}

- (void)warnInUse {
    NSLog(@"The FMDatabase %@ is currently in use.", self);
    
#ifndef NS_BLOCK_ASSERTIONS
    if (_crashOnErrors) {
        abort();
        NSAssert1(false, @"The FMDatabase %@ is currently in use.", self);
    }
#endif
}

- (BOOL)databaseExists {
    
    if (!_db) {
            
        NSLog(@"The FMDatabase %@ is not open.", self);
        
    #ifndef NS_BLOCK_ASSERTIONS
        if (_crashOnErrors) {
            abort();
            NSAssert1(false, @"The FMDatabase %@ is not open.", self);
        }
    #endif
        
        return NO;
    }
    
    return YES;
}

- (NSString*)lastErrorMessage {
    return [NSString stringWithUTF8String:sqlite3_errmsg(_db)];
}

- (BOOL)hadError {
    int lastErrCode = [self lastErrorCode];
    
    return (lastErrCode > SQLITE_OK && lastErrCode < SQLITE_ROW);
}

- (int)lastErrorCode {
    return sqlite3_errcode(_db);
}


- (NSError*)errorWithMessage:(NSString*)message {
    NSDictionary* errorMessage = [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:@"FMDatabase" code:sqlite3_errcode(_db) userInfo:errorMessage];    
}

- (NSError*)lastError {
   return [self errorWithMessage:[self lastErrorMessage]];
}

- (sqlite_int64)lastInsertRowId {
    
    if (_isExecutingStatement) {
        [self warnInUse];
        return NO;
    }
    
    _isExecutingStatement = YES;
    
    sqlite_int64 ret = sqlite3_last_insert_rowid(_db);
    
    _isExecutingStatement = NO;
    
    return ret;
}

- (int)changes {
    if (_isExecutingStatement) {
        [self warnInUse];
        return 0;
    }
    
    _isExecutingStatement = YES;
    
    int ret = sqlite3_changes(_db);
    
    _isExecutingStatement = NO;
    
    return ret;
}

- (void)bindObject:(id)obj toColumn:(int)idx inStatement:(sqlite3_stmt*)pStmt {
    
    if ((!obj) || ((NSNull *)obj == [NSNull null])) {
        sqlite3_bind_null(pStmt, idx);
    }
    
    // FIXME - someday check the return codes on these binds.
    else if ([obj isKindOfClass:[NSData class]]) {
        const void *bytes = [obj bytes];
        if (!bytes) {
            // it's an empty NSData object, aka [NSData data].
            // Don't pass a NULL pointer, or sqlite will bind a SQL null instead of a blob.
            bytes = "";
        }
        sqlite3_bind_blob(pStmt, idx, bytes, (int)[obj length], SQLITE_STATIC);
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
        else if (strcmp([obj objCType], @encode(unsigned long long)) == 0) {
            sqlite3_bind_int64(pStmt, idx, (long long)[obj unsignedLongLongValue]);
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

- (void)extractSQL:(NSString *)sql argumentsList:(va_list)args intoString:(NSMutableString *)cleanedSQL arguments:(NSMutableArray *)arguments {
    
    NSUInteger length = [sql length];
    unichar last = '\0';
    for (NSUInteger i = 0; i < length; ++i) {
        id arg = nil;
        unichar current = [sql characterAtIndex:i];
        unichar add = current;
        if (last == '%') {
            switch (current) {
                case '@':
                    arg = va_arg(args, id);
                    break;
                case 'c':
                    // warning: second argument to 'va_arg' is of promotable type 'char'; this va_arg has undefined behavior because arguments will be promoted to 'int'
                    arg = [NSString stringWithFormat:@"%c", va_arg(args, int)];
                    break;
                case 's':
                    arg = [NSString stringWithUTF8String:va_arg(args, char*)];
                    break;
                case 'd':
                case 'D':
                case 'i':
                    arg = [NSNumber numberWithInt:va_arg(args, int)];
                    break;
                case 'u':
                case 'U':
                    arg = [NSNumber numberWithUnsignedInt:va_arg(args, unsigned int)];
                    break;
                case 'h':
                    i++;
                    if (i < length && [sql characterAtIndex:i] == 'i') {
                        //  warning: second argument to 'va_arg' is of promotable type 'short'; this va_arg has undefined behavior because arguments will be promoted to 'int'
                        arg = [NSNumber numberWithShort:(short)(va_arg(args, int))];
                    }
                    else if (i < length && [sql characterAtIndex:i] == 'u') {
                        // warning: second argument to 'va_arg' is of promotable type 'unsigned short'; this va_arg has undefined behavior because arguments will be promoted to 'int'
                        arg = [NSNumber numberWithUnsignedShort:(unsigned short)(va_arg(args, uint))];
                    }
                    else {
                        i--;
                    }
                    break;
                case 'q':
                    i++;
                    if (i < length && [sql characterAtIndex:i] == 'i') {
                        arg = [NSNumber numberWithLongLong:va_arg(args, long long)];
                    }
                    else if (i < length && [sql characterAtIndex:i] == 'u') {
                        arg = [NSNumber numberWithUnsignedLongLong:va_arg(args, unsigned long long)];
                    }
                    else {
                        i--;
                    }
                    break;
                case 'f':
                    arg = [NSNumber numberWithDouble:va_arg(args, double)];
                    break;
                case 'g':
                    // warning: second argument to 'va_arg' is of promotable type 'float'; this va_arg has undefined behavior because arguments will be promoted to 'double'
                    arg = [NSNumber numberWithFloat:(float)(va_arg(args, double))];
                    break;
                case 'l':
                    i++;
                    if (i < length) {
                        unichar next = [sql characterAtIndex:i];
                        if (next == 'l') {
                            i++;
                            if (i < length && [sql characterAtIndex:i] == 'd') {
                                //%lld
                                arg = [NSNumber numberWithLongLong:va_arg(args, long long)];
                            }
                            else if (i < length && [sql characterAtIndex:i] == 'u') {
                                //%llu
                                arg = [NSNumber numberWithUnsignedLongLong:va_arg(args, unsigned long long)];
                            }
                            else {
                                i--;
                            }
                        }
                        else if (next == 'd') {
                            //%ld
                            arg = [NSNumber numberWithLong:va_arg(args, long)];
                        }
                        else if (next == 'u') {
                            //%lu
                            arg = [NSNumber numberWithUnsignedLong:va_arg(args, unsigned long)];
                        }
                        else {
                            i--;
                        }
                    }
                    else {
                        i--;
                    }
                    break;
                default:
                    // something else that we can't interpret. just pass it on through like normal
                    break;
            }
        }
        else if (current == '%') {
            // percent sign; skip this character
            add = '\0';
        }
        
        if (arg != nil) {
            [cleanedSQL appendString:@"?"];
            [arguments addObject:arg];
        }
        else if (add != '\0') {
            [cleanedSQL appendFormat:@"%C", add];
        }
        last = current;
    }
}

- (FMResultSet *)executeQuery:(NSString *)sql withParameterDictionary:(NSDictionary *)arguments {
    return [self executeQuery:sql withArgumentsInArray:nil orDictionary:arguments orVAList:nil];
}

- (FMResultSet *)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray*)arrayArgs orDictionary:(NSDictionary *)dictionaryArgs orVAList:(va_list)args {
    
    if (![self databaseExists]) {
        return 0x00;
    }
    
    if (_isExecutingStatement) {
        [self warnInUse];
        return 0x00;
    }
    
    _isExecutingStatement = YES;
    
    int rc                  = 0x00;
    sqlite3_stmt *pStmt     = 0x00;
    FMStatement *statement  = 0x00;
    FMResultSet *rs         = 0x00;
    
    if (_traceExecution && sql) {
        NSLog(@"%@ executeQuery: %@", self, sql);
    }
    
    if (_shouldCacheStatements) {
        statement = [self cachedStatementForQuery:sql];
        pStmt = statement ? [statement statement] : 0x00;
    }
    
    int numberOfRetries = 0;
    BOOL retry          = NO;
    
    if (!pStmt) {
        do {
            retry   = NO;
            rc      = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &pStmt, 0);
            
            if (SQLITE_BUSY == rc || SQLITE_LOCKED == rc) {
                retry = YES;
                usleep(20);
                
                if (_busyRetryTimeout && (numberOfRetries++ > _busyRetryTimeout)) {
                    NSLog(@"%s:%d Database busy (%@)", __FUNCTION__, __LINE__, [self databasePath]);
                    NSLog(@"Database busy");
                    sqlite3_finalize(pStmt);
                    _isExecutingStatement = NO;
                    return nil;
                }
            }
            else if (SQLITE_OK != rc) {
                
                if (_logsErrors) {
                    NSLog(@"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]);
                    NSLog(@"DB Query: %@", sql);
                    NSLog(@"DB Path: %@", _databasePath);
#ifndef NS_BLOCK_ASSERTIONS
                    if (_crashOnErrors) {
                        abort();
                        NSAssert2(false, @"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]);
                    }
#endif
                }
                
                sqlite3_finalize(pStmt);
                _isExecutingStatement = NO;
                return nil;
            }
        }
        while (retry);
    }
    
    id obj;
    int idx = 0;
    int queryCount = sqlite3_bind_parameter_count(pStmt); // pointed out by Dominic Yu (thanks!)
    
    // If dictionaryArgs is passed in, that means we are using sqlite's named parameter support
    if (dictionaryArgs) {
        
        for (NSString *dictionaryKey in [dictionaryArgs allKeys]) {
            
            // Prefix the key with a colon.
            NSString *parameterName = [[NSString alloc] initWithFormat:@":%@", dictionaryKey];
            
            // Get the index for the parameter name.
            int namedIdx = sqlite3_bind_parameter_index(pStmt, [parameterName UTF8String]);
            
            FMDBRelease(parameterName);
            
            if (namedIdx > 0) {
                // Standard binding from here.
                [self bindObject:[dictionaryArgs objectForKey:dictionaryKey] toColumn:namedIdx inStatement:pStmt];
                // increment the binding count, so our check below works out
                idx++;
            }
            else {
                NSLog(@"Could not find index for %@", dictionaryKey);
            }
        }
    }
    else {
            
        while (idx < queryCount) {
            
            if (arrayArgs) {
                obj = [arrayArgs objectAtIndex:(NSUInteger)idx];
            }
            else {
                obj = va_arg(args, id);
            }
            
            if (_traceExecution) {
                NSLog(@"obj: %@", obj);
            }
            
            idx++;
            
            [self bindObject:obj toColumn:idx inStatement:pStmt];
        }
    }
    
    if (idx != queryCount) {
        NSLog(@"Error: the bind count is not correct for the # of variables (executeQuery)");
        sqlite3_finalize(pStmt);
        _isExecutingStatement = NO;
        return nil;
    }
    
    FMDBRetain(statement); // to balance the release below
    
    if (!statement) {
        statement = [[FMStatement alloc] init];
        [statement setStatement:pStmt];
        
        if (_shouldCacheStatements) {
            [self setCachedStatement:statement forQuery:sql];
        }
    }
    
    // the statement gets closed in rs's dealloc or [rs close];
    rs = [FMResultSet resultSetWithStatement:statement usingParentDatabase:self];
    [rs setQuery:sql];
    
    NSValue *openResultSet = [NSValue valueWithNonretainedObject:rs];
    [_openResultSets addObject:openResultSet];
    
    [statement setUseCount:[statement useCount] + 1];
    
    FMDBRelease(statement); 
    
    _isExecutingStatement = NO;
    
    return rs;
}

- (FMResultSet *)executeQuery:(NSString*)sql, ... {
    va_list args;
    va_start(args, sql);
    
    id result = [self executeQuery:sql withArgumentsInArray:nil orDictionary:nil orVAList:args];
    
    va_end(args);
    return result;
}

- (FMResultSet *)executeQueryWithFormat:(NSString*)format, ... {
    va_list args;
    va_start(args, format);
    
    NSMutableString *sql = [NSMutableString stringWithCapacity:[format length]];
    NSMutableArray *arguments = [NSMutableArray array];
    [self extractSQL:format argumentsList:args intoString:sql arguments:arguments];    
    
    va_end(args);
    
    return [self executeQuery:sql withArgumentsInArray:arguments];
}

- (FMResultSet *)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray *)arguments {
    return [self executeQuery:sql withArgumentsInArray:arguments orDictionary:nil orVAList:nil];
}

- (BOOL)executeUpdate:(NSString*)sql error:(NSError**)outErr withArgumentsInArray:(NSArray*)arrayArgs orDictionary:(NSDictionary *)dictionaryArgs orVAList:(va_list)args {
    
    if (![self databaseExists]) {
        return NO;
    }
    
    if (_isExecutingStatement) {
        [self warnInUse];
        return NO;
    }
    
    _isExecutingStatement = YES;
    
    int rc                   = 0x00;
    sqlite3_stmt *pStmt      = 0x00;
    FMStatement *cachedStmt  = 0x00;
    
    if (_traceExecution && sql) {
        NSLog(@"%@ executeUpdate: %@", self, sql);
    }
    
    if (_shouldCacheStatements) {
        cachedStmt = [self cachedStatementForQuery:sql];
        pStmt = cachedStmt ? [cachedStmt statement] : 0x00;
    }
    
    int numberOfRetries = 0;
    BOOL retry          = NO;
    
    if (!pStmt) {
        
        do {
            retry   = NO;
            rc      = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &pStmt, 0);
            if (SQLITE_BUSY == rc || SQLITE_LOCKED == rc) {
                retry = YES;
                usleep(20);
                
                if (_busyRetryTimeout && (numberOfRetries++ > _busyRetryTimeout)) {
                    NSLog(@"%s:%d Database busy (%@)", __FUNCTION__, __LINE__, [self databasePath]);
                    NSLog(@"Database busy");
                    sqlite3_finalize(pStmt);
                    _isExecutingStatement = NO;
                    return NO;
                }
            }
            else if (SQLITE_OK != rc) {
                
                if (_logsErrors) {
                    NSLog(@"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]);
                    NSLog(@"DB Query: %@", sql);
                    NSLog(@"DB Path: %@", _databasePath);
#ifndef NS_BLOCK_ASSERTIONS
                    if (_crashOnErrors) {
                        abort();
                        NSAssert2(false, @"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]);
                    }
#endif
                }
                
                sqlite3_finalize(pStmt);
                
                if (outErr) {
                    *outErr = [self errorWithMessage:[NSString stringWithUTF8String:sqlite3_errmsg(_db)]];
                }
                
                _isExecutingStatement = NO;
                return NO;
            }
        }
        while (retry);
    }
    
    id obj;
    int idx = 0;
    int queryCount = sqlite3_bind_parameter_count(pStmt);
    
    // If dictionaryArgs is passed in, that means we are using sqlite's named parameter support
    if (dictionaryArgs) {
        
        for (NSString *dictionaryKey in [dictionaryArgs allKeys]) {
            
            // Prefix the key with a colon.
            NSString *parameterName = [[NSString alloc] initWithFormat:@":%@", dictionaryKey];
            
            // Get the index for the parameter name.
            int namedIdx = sqlite3_bind_parameter_index(pStmt, [parameterName UTF8String]);
            
            FMDBRelease(parameterName);
            
            if (namedIdx > 0) {
                // Standard binding from here.
                [self bindObject:[dictionaryArgs objectForKey:dictionaryKey] toColumn:namedIdx inStatement:pStmt];
                
                // increment the binding count, so our check below works out
                idx++;
            }
            else {
                NSLog(@"Could not find index for %@", dictionaryKey);
            }
        }
    }
    else {
        
        while (idx < queryCount) {
            
            if (arrayArgs) {
                obj = [arrayArgs objectAtIndex:(NSUInteger)idx];
            }
            else {
                obj = va_arg(args, id);
            }
            
            if (_traceExecution) {
                NSLog(@"obj: %@", obj);
            }
            
            idx++;
            
            [self bindObject:obj toColumn:idx inStatement:pStmt];
        }
    }
    
    
    if (idx != queryCount) {
        NSLog(@"Error: the bind count (%d) is not correct for the # of variables in the query (%d) (%@) (executeUpdate)", idx, queryCount, sql);
        sqlite3_finalize(pStmt);
        _isExecutingStatement = NO;
        return NO;
    }
    
    /* Call sqlite3_step() to run the virtual machine. Since the SQL being
     ** executed is not a SELECT statement, we assume no data will be returned.
     */
    numberOfRetries = 0;
    
    do {
        rc      = sqlite3_step(pStmt);
        retry   = NO;
        
        if (SQLITE_BUSY == rc || SQLITE_LOCKED == rc) {
            // this will happen if the db is locked, like if we are doing an update or insert.
            // in that case, retry the step... and maybe wait just 10 milliseconds.
            retry = YES;
            if (SQLITE_LOCKED == rc) {
                rc = sqlite3_reset(pStmt);
                if (rc != SQLITE_LOCKED) {
                    NSLog(@"Unexpected result from sqlite3_reset (%d) eu", rc);
                }
            }
            usleep(20);
            
            if (_busyRetryTimeout && (numberOfRetries++ > _busyRetryTimeout)) {
                NSLog(@"%s:%d Database busy (%@)", __FUNCTION__, __LINE__, [self databasePath]);
                NSLog(@"Database busy");
                retry = NO;
            }
        }
        else if (SQLITE_DONE == rc) {
            // all is well, let's return.
        }
        else if (SQLITE_ERROR == rc) {
            NSLog(@"Error calling sqlite3_step (%d: %s) SQLITE_ERROR", rc, sqlite3_errmsg(_db));
            NSLog(@"DB Query: %@", sql);
        }
        else if (SQLITE_MISUSE == rc) {
            // uh oh.
            NSLog(@"Error calling sqlite3_step (%d: %s) SQLITE_MISUSE", rc, sqlite3_errmsg(_db));
            NSLog(@"DB Query: %@", sql);
        }
        else {
            // wtf?
            NSLog(@"Unknown error calling sqlite3_step (%d: %s) eu", rc, sqlite3_errmsg(_db));
            NSLog(@"DB Query: %@", sql);
        }
        
    } while (retry);
    
    if (rc == SQLITE_ROW) {
        NSAssert1(NO, @"A executeUpdate is being called with a query string '%@'", sql);
    }
    
    if (_shouldCacheStatements && !cachedStmt) {
        cachedStmt = [[FMStatement alloc] init];
        
        [cachedStmt setStatement:pStmt];
        
        [self setCachedStatement:cachedStmt forQuery:sql];
        
        FMDBRelease(cachedStmt);
    }
    
    int closeErrorCode;
    
    if (cachedStmt) {
        [cachedStmt setUseCount:[cachedStmt useCount] + 1];
        closeErrorCode = sqlite3_reset(pStmt);
    }
    else {
        /* Finalize the virtual machine. This releases all memory and other
         ** resources allocated by the sqlite3_prepare() call above.
         */
        closeErrorCode = sqlite3_finalize(pStmt);
    }
    
    if (closeErrorCode != SQLITE_OK) {
        NSLog(@"Unknown error finalizing or resetting statement (%d: %s)", closeErrorCode, sqlite3_errmsg(_db));
        NSLog(@"DB Query: %@", sql);
    }
    
    _isExecutingStatement = NO;
    return (rc == SQLITE_DONE || rc == SQLITE_OK);
}


- (BOOL)executeUpdate:(NSString*)sql, ... {
    va_list args;
    va_start(args, sql);
    
    BOOL result = [self executeUpdate:sql error:nil withArgumentsInArray:nil orDictionary:nil orVAList:args];
    
    va_end(args);
    return result;
}

- (BOOL)executeUpdate:(NSString*)sql withArgumentsInArray:(NSArray *)arguments {
    return [self executeUpdate:sql error:nil withArgumentsInArray:arguments orDictionary:nil orVAList:nil];
}

- (BOOL)executeUpdate:(NSString*)sql withParameterDictionary:(NSDictionary *)arguments {
    return [self executeUpdate:sql error:nil withArgumentsInArray:nil orDictionary:arguments orVAList:nil];
}

- (BOOL)executeUpdateWithFormat:(NSString*)format, ... {
    va_list args;
    va_start(args, format);
    
    NSMutableString *sql      = [NSMutableString stringWithCapacity:[format length]];
    NSMutableArray *arguments = [NSMutableArray array];
    
    [self extractSQL:format argumentsList:args intoString:sql arguments:arguments];    
    
    va_end(args);
    
    return [self executeUpdate:sql withArgumentsInArray:arguments];
}

- (BOOL)update:(NSString*)sql withErrorAndBindings:(NSError**)outErr, ... {
    va_list args;
    va_start(args, outErr);
    
    BOOL result = [self executeUpdate:sql error:outErr withArgumentsInArray:nil orDictionary:nil orVAList:args];
    
    va_end(args);
    return result;
}

- (BOOL)rollback {
    BOOL b = [self executeUpdate:@"rollback transaction"];
    
    if (b) {
        _inTransaction = NO;
    }
    
    return b;
}

- (BOOL)commit {
    BOOL b =  [self executeUpdate:@"commit transaction"];
    
    if (b) {
        _inTransaction = NO;
    }
    
    return b;
}

- (BOOL)beginDeferredTransaction {
    
    BOOL b = [self executeUpdate:@"begin deferred transaction"];
    if (b) {
        _inTransaction = YES;
    }
    
    return b;
}

- (BOOL)beginTransaction {
    
    BOOL b = [self executeUpdate:@"begin exclusive transaction"];
    if (b) {
        _inTransaction = YES;
    }
    
    return b;
}

- (BOOL)inTransaction {
    return _inTransaction;
}

#if SQLITE_VERSION_NUMBER >= 3007000

- (BOOL)startSavePointWithName:(NSString*)name error:(NSError**)outErr {
    
    // FIXME: make sure the savepoint name doesn't have a ' in it.
    
    NSParameterAssert(name);
    
    if (![self executeUpdate:[NSString stringWithFormat:@"savepoint '%@';", name]]) {
        
        if (*outErr) {
            *outErr = [self lastError];
        }
        
        return NO;
    }
    
    return YES;
}

- (BOOL)releaseSavePointWithName:(NSString*)name error:(NSError**)outErr {
    
    NSParameterAssert(name);
    
    BOOL worked = [self executeUpdate:[NSString stringWithFormat:@"release savepoint '%@';", name]];
    
    if (!worked && *outErr) {
        *outErr = [self lastError];
    }
    
    return worked;
}

- (BOOL)rollbackToSavePointWithName:(NSString*)name error:(NSError**)outErr {
    
    NSParameterAssert(name);
    
    BOOL worked = [self executeUpdate:[NSString stringWithFormat:@"rollback transaction to savepoint '%@';", name]];
    
    if (!worked && *outErr) {
        *outErr = [self lastError];
    }
    
    return worked;
}

- (NSError*)inSavePoint:(void (^)(BOOL *rollback))block {
    static unsigned long savePointIdx = 0;
    
    NSString *name = [NSString stringWithFormat:@"dbSavePoint%ld", savePointIdx++];
    
    BOOL shouldRollback = NO;
    
    NSError *err = 0x00;
    
    if (![self startSavePointWithName:name error:&err]) {
        return err;
    }
    
    block(&shouldRollback);
    
    if (shouldRollback) {
        [self rollbackToSavePointWithName:name error:&err];
    }
    else {
        [self releaseSavePointWithName:name error:&err];
    }
    
    return err;
}

#endif


- (BOOL)shouldCacheStatements {
    return _shouldCacheStatements;
}

- (void)setShouldCacheStatements:(BOOL)value {
    
    _shouldCacheStatements = value;
    
    if (_shouldCacheStatements && !_cachedStatements) {
        [self setCachedStatements:[NSMutableDictionary dictionary]];
    }
    
    if (!_shouldCacheStatements) {
        [self setCachedStatements:nil];
    }
}

void FMDBBlockSQLiteCallBackFunction(sqlite3_context *context, int argc, sqlite3_value **argv);
void FMDBBlockSQLiteCallBackFunction(sqlite3_context *context, int argc, sqlite3_value **argv) {
#if ! __has_feature(objc_arc)
    void (^block)(sqlite3_context *context, int argc, sqlite3_value **argv) = (id)sqlite3_user_data(context);
#else
    void (^block)(sqlite3_context *context, int argc, sqlite3_value **argv) = (__bridge id)sqlite3_user_data(context);
#endif
    block(context, argc, argv);
}


- (void)makeFunctionNamed:(NSString*)name maximumArguments:(int)count withBlock:(void (^)(sqlite3_context *context, int argc, sqlite3_value **argv))block {
    
    if (!_openFunctions) {
        _openFunctions = [NSMutableSet new];
    }
    
    id b = FMDBReturnAutoreleased([block copy]);
    
    [_openFunctions addObject:b];
    
    /* I tried adding custom functions to release the block when the connection is destroyed- but they seemed to never be called, so we use _openFunctions to store the values instead. */
#if ! __has_feature(objc_arc)
    sqlite3_create_function([self sqliteHandle], [name UTF8String], count, SQLITE_UTF8, (void*)b, &FMDBBlockSQLiteCallBackFunction, 0x00, 0x00);
#else
    sqlite3_create_function([self sqliteHandle], [name UTF8String], count, SQLITE_UTF8, (__bridge void*)b, &FMDBBlockSQLiteCallBackFunction, 0x00, 0x00);
#endif
}

@end



@implementation FMStatement
@synthesize statement=_statement;
@synthesize query=_query;
@synthesize useCount=_useCount;

- (void)finalize {
    [self close];
    [super finalize];
}

- (void)dealloc {
    [self close];
    FMDBRelease(_query);
#if ! __has_feature(objc_arc)
    [super dealloc];
#endif
}

- (void)close {
    if (_statement) {
        sqlite3_finalize(_statement);
        _statement = 0x00;
    }
}

- (void)reset {
    if (_statement) {
        sqlite3_reset(_statement);
    }
}

- (NSString*)description {
    return [NSString stringWithFormat:@"%@ %ld hit(s) for query %@", [super description], _useCount, _query];
}


@end

