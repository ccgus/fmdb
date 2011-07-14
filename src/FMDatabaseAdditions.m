//
//  FMDatabaseAdditions.m
//  fmkit
//
//  Created by August Mueller on 10/30/05.
//  Copyright 2005 Flying Meat Inc.. All rights reserved.
//

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@interface FMDatabase (PrivateStuff)
- (FMResultSet *)executeQuery:(NSString *)sql withArgumentsInArray:(NSArray*)arrayArgs orDictionary:(NSDictionary *)dictionaryArgs orVAList:(va_list)args;
@end

@implementation FMDatabase (FMDatabaseAdditions)

#define RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(type, sel)             \
va_list args;                                                        \
va_start(args, query);                                               \
FMResultSet *resultSet = [self executeQuery:query withArgumentsInArray:0x00 orDictionary:0x00 orVAList:args];   \
va_end(args);                                                        \
if (![resultSet next]) { return (type)0; }                           \
type ret = [resultSet sel:0];                                        \
[resultSet close];                                                   \
[resultSet setParentDB:nil];                                         \
return ret;


- (NSString*)stringForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(NSString *, stringForColumnIndex);
}

- (int)intForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(int, intForColumnIndex);
}

- (long)longForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(long, longForColumnIndex);
}

- (BOOL)boolForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(BOOL, boolForColumnIndex);
}

- (double)doubleForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(double, doubleForColumnIndex);
}

- (NSData*)dataForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(NSData *, dataForColumnIndex);
}

- (NSDate*)dateForQuery:(NSString*)query, ... {
    RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(NSDate *, dateForColumnIndex);
}


- (BOOL)tableExists:(NSString*)tableName {
    
    tableName = [tableName lowercaseString];
    
    FMResultSet *rs = [self executeQuery:@"select [sql] from sqlite_master where [type] = 'table' and lower(name) = ?", tableName];
    
    //if at least one next exists, table exists
    BOOL returnBool = [rs next];
    
    //close and free object
    [rs close];
    
    return returnBool;
}

/*
 get table with list of tables: result colums: type[STRING], name[STRING],tbl_name[STRING],rootpage[INTEGER],sql[STRING]
 check if table exist in database  (patch from OZLB)
*/
- (FMResultSet*)getSchema {
    
    //result colums: type[STRING], name[STRING],tbl_name[STRING],rootpage[INTEGER],sql[STRING]
    FMResultSet *rs = [self executeQuery:@"SELECT type, name, tbl_name, rootpage, sql FROM (SELECT * FROM sqlite_master UNION ALL SELECT * FROM sqlite_temp_master) WHERE type != 'meta' AND name NOT LIKE 'sqlite_%' ORDER BY tbl_name, type DESC, name"];
    
    return rs;
}

/* 
 get table schema: result colums: cid[INTEGER], name,type [STRING], notnull[INTEGER], dflt_value[],pk[INTEGER]
*/
- (FMResultSet*)getTableSchema:(NSString*)tableName {
    
    //result colums: cid[INTEGER], name,type [STRING], notnull[INTEGER], dflt_value[],pk[INTEGER]
    FMResultSet *rs = [self executeQuery:[NSString stringWithFormat: @"PRAGMA table_info(%@)", tableName]];
    
    return rs;
}


- (BOOL)columnExists:(NSString*)tableName columnName:(NSString*)columnName {
    
    BOOL returnBool = NO;
    
    tableName  = [tableName lowercaseString];
    columnName = [columnName lowercaseString];
    
    FMResultSet *rs = [self getTableSchema:tableName];
    
    //check if column is present in table schema
    while ([rs next]) {
        if ([[[rs stringForColumn:@"name"] lowercaseString] isEqualToString: columnName]) {
            returnBool = YES;
            break;
        }
    }
    
    return returnBool;
}

- (BOOL)validateSQL:(NSString*)sql error:(NSError**)error {
    sqlite3_stmt *pStmt = NULL;
    BOOL validationSucceeded = YES;
    BOOL keepTrying = YES;
    int numberOfRetries = 0;
    
    while (keepTrying == YES) {
        keepTrying = NO;
        int rc = sqlite3_prepare_v2(_db, [sql UTF8String], -1, &pStmt, 0);
        if (rc == SQLITE_BUSY || rc == SQLITE_LOCKED) {
            keepTrying = YES;
            usleep(20);
            
            if (_busyRetryTimeout && (numberOfRetries++ > _busyRetryTimeout)) {
                NSLog(@"%s:%d Database busy (%@)", __FUNCTION__, __LINE__, [self databasePath]);
                NSLog(@"Database busy");
            }          
        } 
        else if (rc != SQLITE_OK) {
            validationSucceeded = NO;
            if (error) {
                *error = [NSError errorWithDomain:NSCocoaErrorDomain 
                                             code:[self lastErrorCode]
                                         userInfo:[NSDictionary dictionaryWithObject:[self lastErrorMessage] 
                                                                              forKey:NSLocalizedDescriptionKey]];
            }
        }
    }
    
    sqlite3_finalize(pStmt);
    
    return validationSucceeded;
}

@end
