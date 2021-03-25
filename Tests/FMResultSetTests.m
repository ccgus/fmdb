//
//  FMResultSetTests.m
//  fmdb
//
//  Created by Muralidharan,Roshan on 10/6/14.
//
//

#import "FMDBTempDBTests.h"
#import "FMDatabase.h"

#if FMDB_SQLITE_STANDALONE
#import <sqlite3/sqlite3.h>
#else
#import <sqlite3.h>
#endif

@interface FMResultSetTests : FMDBTempDBTests

@end

@implementation FMResultSetTests

+ (void)populateDatabase:(FMDatabase *)db
{
    [db executeUpdate:@"create table test (a text, b text, c integer, d double, e double)"];
    
    [db beginTransaction];
    int i = 0;
    while (i++ < 20) {
        [db executeUpdate:@"insert into test (a, b, c, d, e) values (?, ?, ?, ?, ?)" ,
         @"hi'",
         [NSString stringWithFormat:@"number %d", i],
         [NSNumber numberWithInt:i],
         [NSDate date],
         [NSNumber numberWithFloat:2.2f]];
    }
    [db commit];
}

- (void)testNextWithError_WithoutError
{
    [self.db executeUpdate:@"CREATE TABLE testTable(key INTEGER PRIMARY KEY, value INTEGER)"];
    [self.db executeUpdate:@"INSERT INTO testTable (key, value) VALUES (1, 2)"];
    [self.db executeUpdate:@"INSERT INTO testTable (key, value) VALUES (2, 4)"];
    
    FMResultSet *resultSet = [self.db executeQuery:@"SELECT * FROM testTable WHERE key=1"];
    XCTAssertNotNil(resultSet);
    NSError *error;
    XCTAssertTrue([resultSet nextWithError:&error]);
    XCTAssertNil(error);
    
    XCTAssertFalse([resultSet nextWithError:&error]);
    XCTAssertNil(error);
    
    [resultSet close];
}

- (void)testNextWithError_WithBusyError
{
    [self.db executeUpdate:@"CREATE TABLE testTable(key INTEGER PRIMARY KEY, value INTEGER)"];
    [self.db executeUpdate:@"INSERT INTO testTable (key, value) VALUES (1, 2)"];
    [self.db executeUpdate:@"INSERT INTO testTable (key, value) VALUES (2, 4)"];
    
    FMResultSet *resultSet = [self.db executeQuery:@"SELECT * FROM testTable WHERE key=1"];
    XCTAssertNotNil(resultSet);
    
    FMDatabase *newDB = [FMDatabase databaseWithPath:self.databasePath];
    [newDB open];
    
    [newDB beginExclusiveTransaction];
    NSError *error;
    XCTAssertFalse([resultSet nextWithError:&error]);
    [newDB commit];
    
    XCTAssertEqual(error.code, SQLITE_BUSY, @"SQLITE_BUSY should be the last error");
    [resultSet close];
}

- (void)testNextWithError_WithMisuseError
{
    [self.db executeUpdate:@"CREATE TABLE testTable(key INTEGER PRIMARY KEY, value INTEGER)"];
    [self.db executeUpdate:@"INSERT INTO testTable (key, value) VALUES (1, 2)"];
    [self.db executeUpdate:@"INSERT INTO testTable (key, value) VALUES (2, 4)"];
    
    FMResultSet *resultSet = [self.db executeQuery:@"SELECT * FROM testTable WHERE key=9"];
    XCTAssertNotNil(resultSet);
    XCTAssertFalse([resultSet next]);
    NSError *error;
    XCTAssertFalse([resultSet nextWithError:&error]);

    XCTAssertEqual(error.code, SQLITE_MISUSE, @"SQLITE_MISUSE should be the last error");
}

- (void)testColumnTypes
{
    [self.db executeUpdate:@"CREATE TABLE testTable (intValue INTEGER, floatValue FLOAT, textValue TEXT, blobValue BLOB)"];
    NSString *sql = @"INSERT INTO testTable (intValue, floatValue, textValue, blobValue) VALUES (?, ?, ?, ?)";
    NSError *error;
    NSData *data = [@"foo" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *zeroLengthData = [NSData data];
    NSNull *null = [NSNull null];
    [self.db executeUpdate:sql values:@[@42, @M_PI, @"test", data] error:&error];
    [self.db executeUpdate:sql values:@[null, null, null, null] error:&error];
    [self.db executeUpdate:sql values:@[null, null, null, zeroLengthData] error:&error];

    FMResultSet *resultSet = [self.db executeQuery:@"SELECT * FROM testTable"];
    XCTAssertNotNil(resultSet);

    XCTAssertTrue([resultSet next]);
    XCTAssertEqual([resultSet typeForColumn:@"intValue"],   SqliteValueTypeInteger);
    XCTAssertEqual([resultSet typeForColumn:@"floatValue"], SqliteValueTypeFloat);
    XCTAssertEqual([resultSet typeForColumn:@"textValue"],  SqliteValueTypeText);
    XCTAssertEqual([resultSet typeForColumn:@"blobValue"],  SqliteValueTypeBlob);
    XCTAssertNotNil([resultSet dataForColumn:@"blobValue"]);

    XCTAssertTrue([resultSet next]);
    XCTAssertEqual([resultSet typeForColumn:@"intValue"],   SqliteValueTypeNull);
    XCTAssertEqual([resultSet typeForColumn:@"floatValue"], SqliteValueTypeNull);
    XCTAssertEqual([resultSet typeForColumn:@"textValue"],  SqliteValueTypeNull);
    XCTAssertEqual([resultSet typeForColumn:@"blobValue"],  SqliteValueTypeNull);
    XCTAssertNil([resultSet dataForColumn:@"blobValue"]);

    XCTAssertTrue([resultSet next]);
    XCTAssertEqual([resultSet typeForColumn:@"blobValue"],  SqliteValueTypeBlob);
    XCTAssertNil([resultSet dataForColumn:@"blobValue"]);

    [resultSet close];
}

@end
