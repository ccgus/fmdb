//
//  FMDatabaseAdditionsTests.m
//  fmdb
//
//  Created by Graham Dennis on 24/11/2013.
//
//

#import <XCTest/XCTest.h>
#import "FMDatabaseAdditions.h"

@interface TestMigrator : NSObject<FMDatabaseMigrator>

@end

@implementation TestMigrator

-(NSString *)sqlForInitialSchema
{
    return @"CREATE TABLE migration_test\
    (\
    id INTEGER,\
    name VARCHAR(255)\
    )";
}

- (NSString *)sqlForSchemaUpgradeFromVersion:(uint32_t)from toVersion:(uint32_t)to
{
    if (from < to) { // forward migration
        if (from == 1 && to == 2) {
            return @"ALTER TABLE migration_test ADD COLUMN description VARCHAR(255)";
        }
    } else { // backward migration
        if (from == 2 && to == 1) {
            return @"ALTER TABLE migration_test RENAME TO migration_test_tmp;\
            CREATE TABLE migration_test\
            (\
            id INTEGER,\
            name VARCHAR(255)\
            );\
            INSERT INTO migration_test(id,name) (SELECT id,name FROM migration_test_tmp);\
            DROP TABLE migration_test_tmp;";
        }
    }

    return @"unknown migration version";
}

@end

@interface FMDatabaseAdditionsTests : FMDBTempDBTests

@end

@implementation FMDatabaseAdditionsTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testFunkyTableNames
{
    [self.db executeUpdate:@"create table '234 fds' (foo text)"];
    XCTAssertFalse([self.db hadError], @"table creation should have succeeded");
    FMResultSet *rs = [self.db getTableSchema:@"234 fds"];
    XCTAssertTrue([rs next], @"Schema should have succeded");
    [rs close];
    XCTAssertFalse([self.db hadError], @"There shouldn't be any errors");
}

- (void)testBoolForQuery
{
    BOOL result = [self.db boolForQuery:@"SELECT ? not null", @""];
    XCTAssertTrue(result, @"Empty strings should be considered true");
    
    result = [self.db boolForQuery:@"SELECT ? not null", [NSMutableData data]];
    XCTAssertTrue(result, @"Empty mutable data should be considered true");
    
    result = [self.db boolForQuery:@"SELECT ? not null", [NSData data]];
    XCTAssertTrue(result, @"Empty data should be considered true");
}


- (void)testIntForQuery
{
    [self.db executeUpdate:@"create table t1 (a integer)"];
    [self.db executeUpdate:@"insert into t1 values (?)", [NSNumber numberWithInt:5]];
    
    XCTAssertEqual([self.db changes], 1, @"There should only be one change");
    
    int ia = [self.db intForQuery:@"select a from t1 where a = ?", [NSNumber numberWithInt:5]];
    XCTAssertEqual(ia, 5, @"foo");
}

- (void)testDateForQuery
{
    NSDate *date = [NSDate date];
    [self.db executeUpdate:@"create table datetest (a double, b double, c double)"];
    [self.db executeUpdate:@"insert into datetest (a, b, c) values (?, ?, 0)" , [NSNull null], date];

    NSDate *foo = [self.db dateForQuery:@"select b from datetest where c = 0"];
    XCTAssertEqualWithAccuracy([foo timeIntervalSinceDate:date], 0.0, 1.0, @"Dates should be the same to within a second");
}

- (void)testTableExists
{
    XCTAssertTrue([self.db executeUpdate:@"create table t4 (a text, b text)"]);

    XCTAssertTrue([self.db tableExists:@"t4"]);
    XCTAssertFalse([self.db tableExists:@"thisdoesntexist"]);
    
    FMResultSet *rs = [self.db getSchema];
    while ([rs next]) {
        XCTAssertEqualObjects([rs stringForColumn:@"type"], @"table");
    }

}

- (void)testColumnExists
{
    [self.db executeUpdate:@"create table nulltest (a text, b text)"];
    
    XCTAssertTrue([self.db columnExists:@"a" inTableWithName:@"nulltest"]);
    XCTAssertTrue([self.db columnExists:@"b" inTableWithName:@"nulltest"]);
    XCTAssertFalse([self.db columnExists:@"c" inTableWithName:@"nulltest"]);
}

- (void)testUserVersion {
    
    [[self db] setUserVersion:12];
    
    XCTAssertTrue([[self db] userVersion] == 12);
}

- (void)testSchemaMigration {
    TestMigrator* migrator = [[TestMigrator alloc] init];

    [self.db performMigration:1 withMigrator:migrator];

    XCTAssertTrue([self.db tableExists:@"migration_test"]);

    [self.db performMigration:2 withMigrator:migrator];

    XCTAssertTrue([self.db columnExists:@"description" inTableWithName:@"migration_test"]);

    [self.db performMigration:1 withMigrator:migrator];

    XCTAssertFalse([self.db columnExists:@"description" inTableWithName:@"migration_test"]);
}

@end
