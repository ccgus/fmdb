//
//  FMDB.m
//  fmdb
//
//  Created by zxiou on 16/4/28.
//
//

#import "FMDB.h"

@interface FMDB ()

@property(nonatomic, strong)FMDatabase *database;

@end

@implementation FMDB

#pragma mark - Define a single instance of the class
static AXUDataBaseHandle *_dbHandle = nil;

+ (AXUDataBaseHandle *)shareInstance
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _dbHandle = [[self alloc] init];
    }) ;
    
    return _dbHandle ;
}

#pragma mark - The operation of opening the database
- (BOOL)openDataBase
{
    if (_database) {
        return true;
    }
    
//    Get the sandbox file path
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
//    Get the database file path
    NSString *dataBasePath = [documents stringByAppendingPathComponent:@"user.sqlite"];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _queue = [FMDatabaseQueue databaseQueueWithPath:dataBasePath];
    }) ;
    
    _database = [FMDatabase databaseWithPath:dataBasePath];
    
    if ([_database open]){
//        Set up the cache for the database, improve the query efficiency
        _database.shouldCacheStatements = YES;
        NSLog(@"Database has been opened successfully.");
        return true;
    }else{
        NSLog(@"Opening database have failed, path:%@, errorMsg:%@.", _database, [_database lastError]);
        return false;
    }
    
}

#pragma mark - The operation of closing the database
- (void)closeDataBase
{
    if ([_database close]) {
        _database = nil;
        NSLog(@"Database has been closed successfully.");
    }else{
        
        NSLog(@"Closing database have failed, path:%@, errorMsg:%@.", _database, [_database lastError]);
    }
}

#pragma mark - General operation interface on the database
/*
    The user can not use the following operation functions, they can use this
    function to custom operations by using original classes.
*/

- (void) execSqlInFmdb:(void (^)())block
{
//    before use to ensure that the database is open
    if ([self openDataBase]) {
        @try {
            block(_database);
        }
        @catch (NSException *exception) {
            //The exception handling, can also be directly thrown out, so the caller would capture abnormal information
            NSLog(@"FMDBsql exec sql exception: %@", exception);
        }
        @finally {
            [self closeDataBase];
        }
    }
}

/*
    The following functions just have been enclosured by add error handling, the
    user completely can not use those functions just use upper function to custom
    what they want.
*/

#pragma mark - The operation of creating a table
- (void)creatTable:(NSString *)tableName withSql:(NSString *)sql
{
    [self execSqlInFmdb:^(FMDatabase *db){
        
        if (![db tableExists:tableName]) {
            BOOL res = [db executeUpdate:sql];
            if (!res) {
                NSLog(@"error when creating table %@", tableName);
            } else {
                NSLog(@"succeed to creating table %@", tableName);
            }
        }
    }];
}

#pragma mark - The operation of adding data----- executeUpdate
- (void)insertDataIntoDataBase:(NSString *)tableName withSql:(NSString *)sql
{
    [self execSqlInFmdb:^(FMDatabase *db){

        if ([db tableExists:tableName]) {
            BOOL res = [db executeUpdate:sql];
            if (!res) {
                NSLog(@"error when inserting values into table %@", tableName);
            } else {
                NSLog(@"succeed to insert values into table %@", tableName);
            }
        }
    }];
}

#pragma mark - The operation of deleting data----- executeUpdate
- (void)deleteDataFromDataBase:(NSString *)tableName withSql:(NSString *)sql
{
    [self execSqlInFmdb:^(FMDatabase *db){

        if ([db tableExists:tableName]) {
            BOOL res = [db executeUpdate:sql];
            if (!res) {
                NSLog(@"error when deleting values into table %@", tableName);
            } else {
                NSLog(@"succeed to delete values into table %@", tableName);
            }
        }
    }];
}

#pragma mark - The operation of updating data----- executeUpdate
- (void)updateDataFromDataBase:(NSString *)tableName withSql:(NSString *)sql
{
    [self execSqlInFmdb:^(FMDatabase *db){

        if ([db tableExists:tableName]) {
            BOOL res = [db executeUpdate:sql];
            if (!res) {
                NSLog(@"error when updating values into table %@", tableName);
            } else {
                NSLog(@"succeed to update values into table %@", tableName);
            }
        }
    }];
}

@end
