//
//  Tests.m
//  Tests
//
//  Created by Graham Dennis on 24/11/2013.
//
//

#import "FMDBTempDBTests.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

#if FMDB_SQLITE_STANDALONE
#import <sqlite3/sqlite3.h>
#else
#import <sqlite3.h>
#endif


@interface FMDatabaseTests : FMDBTempDBTests

@end

@implementation FMDatabaseTests

+ (void)populateDatabase:(FMDatabase *)db {
    [db executeUpdate:@"create table test (a text, b text, c integer, d double, e double)"];
    
    [db beginTransaction];
    int i = 0;
    while (i++ < 20) {
        [db executeUpdate:@"insert into test (a, b, c, d, e) values (?, ?, ?, ?, ?)" ,
         @"hi'", // look!  I put in a ', and I'm not escaping it!
         [NSString stringWithFormat:@"number %d", i],
         [NSNumber numberWithInt:i],
         [NSDate date],
         [NSNumber numberWithFloat:2.2f]];
    }
    [db commit];
    
    // do it again, just because
    [db beginTransaction];
    i = 0;
    while (i++ < 20) {
        [db executeUpdate:@"insert into test (a, b, c, d, e) values (?, ?, ?, ?, ?)" ,
         @"hi again'", // look!  I put in a ', and I'm not escaping it!
         [NSString stringWithFormat:@"number %d", i],
         [NSNumber numberWithInt:i],
         [NSDate date],
         [NSNumber numberWithFloat:2.2f]];
    }
    [db commit];
    
    [db executeUpdate:@"create table t3 (a somevalue)"];
    
    [db beginTransaction];
    for (int i=0; i < 20; i++) {
        [db executeUpdate:@"insert into t3 (a) values (?)", [NSNumber numberWithInt:i]];
    }
    [db commit];
}

- (void)setUp{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testOpenWithVFS {
    // create custom vfs
    sqlite3_vfs vfs = *sqlite3_vfs_find(NULL);
    vfs.zName = "MyCustomVFS";
    XCTAssertEqual(SQLITE_OK, sqlite3_vfs_register(&vfs, 0));
    // use custom vfs to open a in memory database
    FMDatabase *db = [[FMDatabase alloc] initWithPath:@":memory:"];
    [db openWithFlags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE vfs:@"MyCustomVFS"];
    XCTAssertFalse([db hadError], @"Open with a custom VFS should have succeeded");
    XCTAssertEqual(SQLITE_OK, sqlite3_vfs_unregister(&vfs));
}

- (void)testURLOpen {
    NSURL *tempFolder = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *fileURL = [tempFolder URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    
    FMDatabase *db = [FMDatabase databaseWithURL:fileURL];
    XCTAssert(db, @"Database should be returned");
    XCTAssertTrue([db open], @"Open should succeed");
    XCTAssertEqualObjects([db databaseURL], fileURL);
    XCTAssertTrue([db close], @"close should succeed");
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
}

- (void)testFailOnOpenWithUnknownVFS {
    FMDatabase *db = [[FMDatabase alloc] initWithPath:@":memory:"];
    [db openWithFlags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE vfs:@"UnknownVFS"];
    XCTAssertTrue([db hadError], @"Should have failed");    
}

- (void)testFailOnUnopenedDatabase {
    [self.db close];
    
    XCTAssertNil([self.db executeQuery:@"select * from table"], @"Shouldn't get results from an empty table");
    XCTAssertTrue([self.db hadError], @"Should have failed");
}

- (void)testFailOnBadStatement {
    XCTAssertFalse([self.db executeUpdate:@"blah blah blah"], @"Invalid statement should fail");
    XCTAssertTrue([self.db hadError], @"Should have failed");
}

- (void)testFailOnBadStatementWithError
{
    NSError *error = nil;
    XCTAssertFalse([self.db executeUpdate:@"blah blah blah" withErrorAndBindings:&error], @"Invalid statement should fail");
    XCTAssertNotNil(error, @"Should have a non-nil NSError");
    XCTAssertEqual([error code], (NSInteger)SQLITE_ERROR, @"Error should be SQLITE_ERROR");
}

- (void)testPragmaJournalMode
{
    FMResultSet *ps = [self.db executeQuery:@"pragma journal_mode=delete"];
    XCTAssertFalse([self.db hadError], @"pragma should have succeeded");
    XCTAssertNotNil(ps, @"Result set should be non-nil");
    XCTAssertTrue([ps next], @"Result set should have a next result");
    [ps close];
}

- (void)testPragmaPageSize
{
    [self.db executeUpdate:@"PRAGMA page_size=2048"];
    XCTAssertFalse([self.db hadError], @"pragma should have succeeded");
}

- (void)testVacuum
{
    [self.db executeUpdate:@"VACUUM"];
    XCTAssertFalse([self.db hadError], @"VACUUM should have succeeded");
}

- (void)testSelectULL
{
    // Unsigned long long
    [self.db executeUpdate:@"create table ull (a integer)"];
    
    [self.db executeUpdate:@"insert into ull (a) values (?)", [NSNumber numberWithUnsignedLongLong:ULLONG_MAX]];
    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
    
    FMResultSet *rs = [self.db executeQuery:@"select a from ull"];
    while ([rs next]) {
        XCTAssertEqual([rs unsignedLongLongIntForColumnIndex:0], ULLONG_MAX, @"Result should be ULLONG_MAX");
        XCTAssertEqual([rs unsignedLongLongIntForColumn:@"a"],   ULLONG_MAX, @"Result should be ULLONG_MAX");
    }
    
    [rs close];
    XCTAssertFalse([self.db hasOpenResultSets], @"Shouldn't have any open result sets");
    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
}

- (void)testSelectByColumnName
{
    FMResultSet *rs = [self.db executeQuery:@"select rowid,* from test where a = ?", @"hi"];
    
    XCTAssertNotNil(rs, @"Should have a non-nil result set");
    
    while ([rs next]) {
        [rs intForColumn:@"c"];
        XCTAssertNotNil([rs stringForColumn:@"b"], @"Should have non-nil string for 'b'");
        XCTAssertNotNil([rs stringForColumn:@"a"], @"Should have non-nil string for 'a'");
        XCTAssertNotNil([rs stringForColumn:@"rowid"], @"Should have non-nil string for 'rowid'");
        XCTAssertNotNil([rs dateForColumn:@"d"], @"Should have non-nil date for 'd'");
        [rs doubleForColumn:@"d"];
        [rs doubleForColumn:@"e"];
        
        XCTAssertEqualObjects([rs columnNameForIndex:0], @"rowid",  @"Wrong column name for result set column number");
        XCTAssertEqualObjects([rs columnNameForIndex:1], @"a",      @"Wrong column name for result set column number");
    }
    
    [rs close];
    XCTAssertFalse([self.db hasOpenResultSets], @"Shouldn't have any open result sets");
    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
}

- (void)testInvalidColumnNames
{
    FMResultSet *rs = [self.db executeQuery:@"select rowid, a, b, c from test"];
    
    XCTAssertNotNil(rs, @"Should have a non-nil result set");
    
    NSString *invalidColumnName = @"foobar";

    while ([rs next]) {
        XCTAssertNil(rs[invalidColumnName], @"Invalid column name should return nil");
        XCTAssertNil([rs stringForColumn:invalidColumnName], @"Invalid column name should return nil");
        XCTAssertEqual([rs UTF8StringForColumn:invalidColumnName], (const unsigned char *)0, @"Invalid column name should return nil");
        XCTAssertNil([rs dateForColumn:invalidColumnName], @"Invalid column name should return nil");
        XCTAssertNil([rs dataForColumn:invalidColumnName], @"Invalid column name should return nil");
        XCTAssertNil([rs dataNoCopyForColumn:invalidColumnName], @"Invalid column name should return nil");
        XCTAssertNil([rs objectForColumn:invalidColumnName], @"Invalid column name should return nil");
    }
    
    [rs close];
    XCTAssertFalse([self.db hasOpenResultSets], @"Shouldn't have any open result sets");
    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
}

- (void)testInvalidColumnIndexes
{
    FMResultSet *rs = [self.db executeQuery:@"select rowid, a, b, c from test"];
    
    XCTAssertNotNil(rs, @"Should have a non-nil result set");
    
    int invalidColumnIndex = 999;
    
    while ([rs next]) {
        XCTAssertNil(rs[invalidColumnIndex], @"Invalid column name should return nil");
        XCTAssertNil([rs stringForColumnIndex:invalidColumnIndex], @"Invalid column name should return nil");
        XCTAssertEqual([rs UTF8StringForColumnIndex:invalidColumnIndex], (const unsigned char *)0, @"Invalid column name should return nil");
        XCTAssertNil([rs dateForColumnIndex:invalidColumnIndex], @"Invalid column name should return nil");
        XCTAssertNil([rs dataForColumnIndex:invalidColumnIndex], @"Invalid column name should return nil");
        XCTAssertNil([rs dataNoCopyForColumnIndex:invalidColumnIndex], @"Invalid column name should return nil");
        XCTAssertNil([rs objectForColumnIndex:invalidColumnIndex], @"Invalid column name should return nil");
    }
    
    [rs close];
    XCTAssertFalse([self.db hasOpenResultSets], @"Shouldn't have any open result sets");
    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
}

- (void)testBusyRetryTimeout
{
    [self.db executeUpdate:@"create table t1 (a integer)"];
    [self.db executeUpdate:@"insert into t1 values (?)", [NSNumber numberWithInt:5]];
    
    [self.db setMaxBusyRetryTimeInterval:2];
    
    FMDatabase *newDB = [FMDatabase databaseWithPath:self.databasePath];
    [newDB open];
    
    FMResultSet *rs = [newDB executeQuery:@"select rowid,* from test where a = ?", @"hi'"];
    [rs next]; // just grab one... which will keep the db locked
    
    XCTAssertFalse([self.db executeUpdate:@"insert into t1 values (5)"], @"Insert should fail because the db is locked by a read");
    XCTAssertEqual([self.db lastErrorCode], SQLITE_BUSY, @"SQLITE_BUSY should be the last error");
    
    [rs close];
    [newDB close];
    
    XCTAssertTrue([self.db executeUpdate:@"insert into t1 values (5)"], @"The database shouldn't be locked at this point");
}

- (void)testCaseSensitiveResultDictionary
{
    // case sensitive result dictionary test
    [self.db executeUpdate:@"create table cs (aRowName integer, bRowName text)"];
    [self.db executeUpdate:@"insert into cs (aRowName, bRowName) values (?, ?)", [NSNumber numberWithBool:1], @"hello"];

    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");

    FMResultSet *rs = [self.db executeQuery:@"select * from cs"];
    while ([rs next]) {
        NSDictionary *d = [rs resultDictionary];
        
        XCTAssertNotNil([d objectForKey:@"aRowName"], @"aRowName should be non-nil");
        XCTAssertNil([d objectForKey:@"arowname"], @"arowname should be nil");
        XCTAssertNotNil([d objectForKey:@"bRowName"], @"bRowName should be non-nil");
        XCTAssertNil([d objectForKey:@"browname"], @"browname should be nil");
    }
    
    [rs close];
    XCTAssertFalse([self.db hasOpenResultSets], @"Shouldn't have any open result sets");
    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
}

- (void)testBoolInsert
{
    [self.db executeUpdate:@"create table btest (aRowName integer)"];
    [self.db executeUpdate:@"insert into btest (aRowName) values (?)", [NSNumber numberWithBool:12]];
    
    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
    
    FMResultSet *rs = [self.db executeQuery:@"select * from btest"];
    while ([rs next]) {
        
        XCTAssertTrue([rs boolForColumnIndex:0], @"first column should be true.");
        XCTAssertTrue([rs intForColumnIndex:0] == 1, @"first column should be equal to 1 - it was %d.", [rs intForColumnIndex:0]);
    }
    
    [rs close];
    XCTAssertFalse([self.db hasOpenResultSets], @"Shouldn't have any open result sets");
    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
}

- (void)testNamedParametersCount
{
    XCTAssertTrue([self.db executeUpdate:@"create table namedparamcounttest (a text, b text, c integer, d double)"]);

    NSMutableDictionary *dictionaryArgs = [NSMutableDictionary dictionary];
    [dictionaryArgs setObject:@"Text1" forKey:@"a"];
    [dictionaryArgs setObject:@"Text2" forKey:@"b"];
    [dictionaryArgs setObject:[NSNumber numberWithInt:1] forKey:@"c"];
    [dictionaryArgs setObject:[NSNumber numberWithDouble:2.0] forKey:@"d"];
    XCTAssertTrue([self.db executeUpdate:@"insert into namedparamcounttest values (:a, :b, :c, :d)" withParameterDictionary:dictionaryArgs]);
    
    FMResultSet *rs = [self.db executeQuery:@"select * from namedparamcounttest"];
    
    XCTAssertNotNil(rs);
    
    [rs next];
    
    XCTAssertEqualObjects([rs stringForColumn:@"a"], @"Text1");
    XCTAssertEqualObjects([rs stringForColumn:@"b"], @"Text2");
    XCTAssertEqual([rs intForColumn:@"c"], 1);
    XCTAssertEqual([rs doubleForColumn:@"d"], 2.0);
    
    [rs close];
    
    // note that at this point, dictionaryArgs has way more values than we need, but the query should still work since
    // a is in there, and that's all we need.
    rs = [self.db executeQuery:@"select * from namedparamcounttest where a = :a" withParameterDictionary:dictionaryArgs];
    
    XCTAssertNotNil(rs);
    XCTAssertTrue([rs next]);
    [rs close];
    
    // ***** Please note the following codes *****
    
    dictionaryArgs = [NSMutableDictionary dictionary];
    
    [dictionaryArgs setObject:@"NewText1" forKey:@"a"];
    [dictionaryArgs setObject:@"NewText2" forKey:@"b"];
    [dictionaryArgs setObject:@"OneMoreText" forKey:@"OneMore"];
    
    XCTAssertTrue([self.db executeUpdate:@"update namedparamcounttest set a = :a, b = :b where b = 'Text2'" withParameterDictionary:dictionaryArgs]);
    
}

- (void)testBlobs
{
    [self.db executeUpdate:@"create table blobTable (a text, b blob)"];
    
    // let's read an image from safari's app bundle.
    NSData *safariCompass = [NSData dataWithContentsOfFile:@"/Applications/Safari.app/Contents/Resources/compass.icns"];
    if (safariCompass) {
        [self.db executeUpdate:@"insert into blobTable (a, b) values (?, ?)", @"safari's compass", safariCompass];
        
        FMResultSet *rs = [self.db executeQuery:@"select b from blobTable where a = ?", @"safari's compass"];
        XCTAssertTrue([rs next]);
        NSData *readData = [rs dataForColumn:@"b"];
        XCTAssertEqualObjects(readData, safariCompass);
        
        // ye shall read the header for this function, or suffer the consequences.
        NSData *readDataNoCopy = [rs dataNoCopyForColumn:@"b"];
        XCTAssertEqualObjects(readDataNoCopy, safariCompass);
        
        [rs close];
        XCTAssertFalse([self.db hasOpenResultSets], @"Shouldn't have any open result sets");
        XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
    }
}

- (void)testNullValues
{
    [self.db executeUpdate:@"create table t2 (a integer, b integer)"];
    
    BOOL result = [self.db executeUpdate:@"insert into t2 values (?, ?)", nil, [NSNumber numberWithInt:5]];
    XCTAssertTrue(result, @"Failed to insert a nil value");
    
    FMResultSet *rs = [self.db executeQuery:@"select * from t2"];
    while ([rs next]) {
        XCTAssertNil([rs stringForColumnIndex:0], @"Wasn't able to retrieve a null string");
        XCTAssertEqualObjects([rs stringForColumnIndex:1], @"5");
    }
    
    [rs close];
    XCTAssertFalse([self.db hasOpenResultSets], @"Shouldn't have any open result sets");
    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
}

- (void)testNestedResultSets
{
    FMResultSet *rs = [self.db executeQuery:@"select * from t3"];
    while ([rs next]) {
        int foo = [rs intForColumnIndex:0];
        
        int newVal = foo + 100;
        
        [self.db executeUpdate:@"update t3 set a = ? where a = ?", [NSNumber numberWithInt:newVal], [NSNumber numberWithInt:foo]];
        
        FMResultSet *rs2 = [self.db executeQuery:@"select a from t3 where a = ?", [NSNumber numberWithInt:newVal]];
        [rs2 next];
        
        XCTAssertEqual([rs2 intForColumnIndex:0], newVal);
        
        [rs2 close];
    }
    [rs close];
    XCTAssertFalse([self.db hasOpenResultSets], @"Shouldn't have any open result sets");
    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
}

- (void)testNSNullInsertion
{
    [self.db executeUpdate:@"create table nulltest (a text, b text)"];
    
    [self.db executeUpdate:@"insert into nulltest (a, b) values (?, ?)", [NSNull null], @"a"];
    [self.db executeUpdate:@"insert into nulltest (a, b) values (?, ?)", nil, @"b"];
    
    FMResultSet *rs = [self.db executeQuery:@"select * from nulltest"];
    
    while ([rs next]) {
        XCTAssertNil([rs stringForColumnIndex:0]);
        XCTAssertNotNil([rs stringForColumnIndex:1]);
    }
    
    [rs close];
    
    XCTAssertFalse([self.db hasOpenResultSets], @"Shouldn't have any open result sets");
    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
}

- (void)testNullDates
{
    NSDate *date = [NSDate date];
    [self.db executeUpdate:@"create table datetest (a double, b double, c double)"];
    [self.db executeUpdate:@"insert into datetest (a, b, c) values (?, ?, 0)" , [NSNull null], date];
    
    FMResultSet *rs = [self.db executeQuery:@"select * from datetest"];
    
    XCTAssertNotNil(rs);
    
    while ([rs next]) {
        
        NSDate *b = [rs dateForColumnIndex:1];
        NSDate *c = [rs dateForColumnIndex:2];
        
        XCTAssertNil([rs dateForColumnIndex:0]);
        XCTAssertNotNil(c, @"zero date shouldn't be nil");
        
        XCTAssertEqualWithAccuracy([b timeIntervalSinceDate:date],  0.0, 1.0, @"Dates should be the same to within a second");
        XCTAssertEqualWithAccuracy([c timeIntervalSince1970],       0.0, 1.0, @"Dates should be the same to within a second");
    }
    [rs close];
    
    XCTAssertFalse([self.db hasOpenResultSets], @"Shouldn't have any open result sets");
    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
}

- (void)testLotsOfNULLs
{
    NSData *safariCompass = [NSData dataWithContentsOfFile:@"/Applications/Safari.app/Contents/Resources/compass.icns"];
    
    if (!safariCompass)
        return;
    
    [self.db executeUpdate:@"create table nulltest2 (s text, d data, i integer, f double, b integer)"];
    
    [self.db executeUpdate:@"insert into nulltest2 (s, d, i, f, b) values (?, ?, ?, ?, ?)" , @"Hi", safariCompass, [NSNumber numberWithInt:12], [NSNumber numberWithFloat:4.4f], [NSNumber numberWithBool:YES]];
    [self.db executeUpdate:@"insert into nulltest2 (s, d, i, f, b) values (?, ?, ?, ?, ?)" , nil, nil, nil, nil, [NSNull null]];
    
    FMResultSet *rs = [self.db executeQuery:@"select * from nulltest2"];
    
    while ([rs next]) {
        
        int i = [rs intForColumnIndex:2];
        
        if (i == 12) {
            // it's the first row we inserted.
            XCTAssertFalse([rs columnIndexIsNull:0]);
            XCTAssertFalse([rs columnIndexIsNull:1]);
            XCTAssertFalse([rs columnIndexIsNull:2]);
            XCTAssertFalse([rs columnIndexIsNull:3]);
            XCTAssertFalse([rs columnIndexIsNull:4]);
            XCTAssertTrue( [rs columnIndexIsNull:5]);
            
            XCTAssertEqualObjects([rs dataForColumn:@"d"], safariCompass);
            XCTAssertNil([rs dataForColumn:@"notthere"]);
            XCTAssertNil([rs stringForColumnIndex:-2], @"Negative columns should return nil results");
            XCTAssertTrue([rs boolForColumnIndex:4]);
            XCTAssertTrue([rs boolForColumn:@"b"]);
            
            XCTAssertEqualWithAccuracy(4.4, [rs doubleForColumn:@"f"], 0.0000001, @"Saving a float and returning it as a double shouldn't change the result much");
            
            XCTAssertEqual([rs intForColumn:@"i"], 12);
            XCTAssertEqual([rs intForColumnIndex:2], 12);
            
            XCTAssertEqual([rs intForColumnIndex:12],       0, @"Non-existent columns should return zero for ints");
            XCTAssertEqual([rs intForColumn:@"notthere"],   0, @"Non-existent columns should return zero for ints");
            
            XCTAssertEqual([rs longForColumn:@"i"], 12l);
            XCTAssertEqual([rs longLongIntForColumn:@"i"], 12ll);
        }
        else {
            // let's test various null things.
            
            XCTAssertTrue([rs columnIndexIsNull:0]);
            XCTAssertTrue([rs columnIndexIsNull:1]);
            XCTAssertTrue([rs columnIndexIsNull:2]);
            XCTAssertTrue([rs columnIndexIsNull:3]);
            XCTAssertTrue([rs columnIndexIsNull:4]);
            XCTAssertTrue([rs columnIndexIsNull:5]);
            
            
            XCTAssertNil([rs dataForColumn:@"d"]);
        }
    }
    
    [rs close];
    XCTAssertFalse([self.db hasOpenResultSets], @"Shouldn't have any open result sets");
    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
}

- (void)testUTF8Strings
{
    [self.db executeUpdate:@"create table utest (a text)"];
    [self.db executeUpdate:@"insert into utest values (?)", @"/übertest"];
    
    FMResultSet *rs = [self.db executeQuery:@"select * from utest where a = ?", @"/übertest"];
    XCTAssertTrue([rs next]);
    [rs close];
    XCTAssertFalse([self.db hasOpenResultSets], @"Shouldn't have any open result sets");
    XCTAssertFalse([self.db hadError], @"Shouldn't have any errors");
}

- (void)testArgumentsInArray
{
    [self.db executeUpdate:@"create table testOneHundredTwelvePointTwo (a text, b integer)"];
    [self.db executeUpdate:@"insert into testOneHundredTwelvePointTwo values (?, ?)" withArgumentsInArray:[NSArray arrayWithObjects:@"one", [NSNumber numberWithInteger:2], nil]];
    [self.db executeUpdate:@"insert into testOneHundredTwelvePointTwo values (?, ?)" withArgumentsInArray:[NSArray arrayWithObjects:@"one", [NSNumber numberWithInteger:3], nil]];
    
    
    FMResultSet *rs = [self.db executeQuery:@"select * from testOneHundredTwelvePointTwo where b > ?" withArgumentsInArray:[NSArray arrayWithObject:[NSNumber numberWithInteger:1]]];
    
    XCTAssertTrue([rs next]);
    
    XCTAssertTrue([rs hasAnotherRow]);
    XCTAssertFalse([self.db hadError]);
    
    XCTAssertEqualObjects([rs stringForColumnIndex:0], @"one");
    XCTAssertEqual([rs intForColumnIndex:1], 2);
    
    XCTAssertTrue([rs next]);
    
    XCTAssertEqual([rs intForColumnIndex:1], 3);
    
    XCTAssertFalse([rs next]);
    XCTAssertFalse([rs hasAnotherRow]);
}

- (void)testColumnNamesContainingPeriods
{
    XCTAssertTrue([self.db executeUpdate:@"create table t4 (a text, b text)"]);
    [self.db executeUpdate:@"insert into t4 (a, b) values (?, ?)", @"one", @"two"];
    
    FMResultSet *rs = [self.db executeQuery:@"select t4.a as 't4.a', t4.b from t4;"];
    
    XCTAssertNotNil(rs);
    
    XCTAssertTrue([rs next]);
    
    XCTAssertEqualObjects([rs stringForColumn:@"t4.a"], @"one");
    XCTAssertEqualObjects([rs stringForColumn:@"b"], @"two");
    
    XCTAssertEqual(strcmp((const char*)[rs UTF8StringForColumn:@"b"], "two"), 0, @"String comparison should return zero");
    
    [rs close];
    
    // let's try these again, with the withArgumentsInArray: variation
    XCTAssertTrue([self.db executeUpdate:@"drop table t4;" withArgumentsInArray:[NSArray array]]);
    XCTAssertTrue([self.db executeUpdate:@"create table t4 (a text, b text)" withArgumentsInArray:[NSArray array]]);
    
    [self.db executeUpdate:@"insert into t4 (a, b) values (?, ?)" withArgumentsInArray:[NSArray arrayWithObjects:@"one", @"two", nil]];
    
    rs = [self.db executeQuery:@"select t4.a as 't4.a', t4.b from t4;" withArgumentsInArray:[NSArray array]];
    
    XCTAssertNotNil(rs);
    
    XCTAssertTrue([rs next]);
    
    XCTAssertEqualObjects([rs stringForColumn:@"t4.a"], @"one");
    XCTAssertEqualObjects([rs stringForColumn:@"b"], @"two");
    
    XCTAssertEqual(strcmp((const char*)[rs UTF8StringForColumn:@"b"], "two"), 0, @"String comparison should return zero");
    
    [rs close];
}

- (void)testFormatStringParsing
{
    XCTAssertTrue([self.db executeUpdate:@"create table t5 (a text, b int, c blob, d text, e text)"]);
    [self.db executeUpdateWithFormat:@"insert into t5 values (%s, %d, %@, %c, %lld)", "text", 42, @"BLOB", 'd', 12345678901234ll];
    
    FMResultSet *rs = [self.db executeQueryWithFormat:@"select * from t5 where a = %s and a = %@ and b = %d", "text", @"text", 42];
    XCTAssertNotNil(rs);
    
    XCTAssertTrue([rs next]);
    
    XCTAssertEqualObjects([rs stringForColumn:@"a"], @"text");
    XCTAssertEqual([rs intForColumn:@"b"], 42);
    XCTAssertEqualObjects([rs stringForColumn:@"c"], @"BLOB");
    XCTAssertEqualObjects([rs stringForColumn:@"d"], @"d");
    XCTAssertEqual([rs longLongIntForColumn:@"e"], 12345678901234ll);
    
    [rs close];
}

- (void)testFormatStringParsingWithSizePrefixes
{
    XCTAssertTrue([self.db executeUpdate:@"create table t55 (a text, b int, c float)"]);
    short testShort = -4;
    float testFloat = 5.5;
    [self.db executeUpdateWithFormat:@"insert into t55 values (%c, %hi, %g)", 'a', testShort, testFloat];
    
    unsigned short testUShort = 6;
    [self.db executeUpdateWithFormat:@"insert into t55 values (%c, %hu, %g)", 'a', testUShort, testFloat];
    
    
    FMResultSet *rs = [self.db executeQueryWithFormat:@"select * from t55 where a = %s order by 2", "a"];
    XCTAssertNotNil(rs);
    
    XCTAssertTrue([rs next]);
    
    XCTAssertEqualObjects([rs stringForColumn:@"a"], @"a");
    XCTAssertEqual([rs intForColumn:@"b"], -4);
    XCTAssertEqualObjects([rs stringForColumn:@"c"], @"5.5");
    
    
    XCTAssertTrue([rs next]);
    
    XCTAssertEqualObjects([rs stringForColumn:@"a"], @"a");
    XCTAssertEqual([rs intForColumn:@"b"], 6);
    XCTAssertEqualObjects([rs stringForColumn:@"c"], @"5.5");
    
    [rs close];
}

- (void)testFormatStringParsingWithNilValue
{
    XCTAssertTrue([self.db executeUpdate:@"create table tatwhat (a text)"]);
    
    BOOL worked = [self.db executeUpdateWithFormat:@"insert into tatwhat values(%@)", nil];
    
    XCTAssertTrue(worked);
    
    FMResultSet *rs = [self.db executeQueryWithFormat:@"select * from tatwhat"];
    XCTAssertNotNil(rs);
    XCTAssertTrue([rs next]);
    XCTAssertTrue([rs columnIndexIsNull:0]);
    
    XCTAssertFalse([rs next]);
}

- (void)testUpdateWithErrorAndBindings
{
    XCTAssertTrue([self.db executeUpdate:@"create table t5 (a text, b int, c blob, d text, e text)"]);
    
    NSError *err = nil;
    BOOL result = [self.db executeUpdate:@"insert into t5 values (?, ?, ?, ?, ?)" withErrorAndBindings:&err, @"text", [NSNumber numberWithInt:42], @"BLOB", @"d", [NSNumber numberWithInt:0]];
    XCTAssertTrue(result);
}

- (void)testSelectWithEmptyArgumentsArray
{
    FMResultSet *rs = [self.db executeQuery:@"select * from test where a=?" withArgumentsInArray:@[]];
    XCTAssertNil(rs);
}

- (void)testDatabaseAttach
{
    NSFileManager *fileManager = [NSFileManager new];
    [fileManager removeItemAtPath:@"/tmp/attachme.db" error:nil];
    
    FMDatabase *dbB = [FMDatabase databaseWithPath:@"/tmp/attachme.db"];
    XCTAssertTrue([dbB open]);
    XCTAssertTrue([dbB executeUpdate:@"create table attached (a text)"]);
    XCTAssertTrue(([dbB executeUpdate:@"insert into attached values (?)", @"test"]));
    XCTAssertTrue([dbB close]);
    
    [self.db executeUpdate:@"attach database '/tmp/attachme.db' as attack"];
    
    FMResultSet *rs = [self.db executeQuery:@"select * from attack.attached"];
    XCTAssertNotNil(rs);
    XCTAssertTrue([rs next]);
    [rs close];
}

- (void)testNamedParameters
{
    // -------------------------------------------------------------------------------
    // Named parameters.
    XCTAssertTrue([self.db executeUpdate:@"create table namedparamtest (a text, b text, c integer, d double)"]);
    
    NSMutableDictionary *dictionaryArgs = [NSMutableDictionary dictionary];
    [dictionaryArgs setObject:@"Text1" forKey:@"a"];
    [dictionaryArgs setObject:@"Text2" forKey:@"b"];
    [dictionaryArgs setObject:[NSNumber numberWithInt:1] forKey:@"c"];
    [dictionaryArgs setObject:[NSNumber numberWithDouble:2.0] forKey:@"d"];
    XCTAssertTrue([self.db executeUpdate:@"insert into namedparamtest values (:a, :b, :c, :d)" withParameterDictionary:dictionaryArgs]);
    
    FMResultSet *rs = [self.db executeQuery:@"select * from namedparamtest"];
    
    XCTAssertNotNil(rs);
    XCTAssertTrue([rs next]);
    
    XCTAssertEqualObjects([rs stringForColumn:@"a"], @"Text1");
    XCTAssertEqualObjects([rs stringForColumn:@"b"], @"Text2");
    XCTAssertEqual([rs intForColumn:@"c"], 1);
    XCTAssertEqual([rs doubleForColumn:@"d"], 2.0);
    
    [rs close];
    
    
    dictionaryArgs = [NSMutableDictionary dictionary];
    
    [dictionaryArgs setObject:@"Text2" forKey:@"blah"];
    
    rs = [self.db executeQuery:@"select * from namedparamtest where b = :blah" withParameterDictionary:dictionaryArgs];
    
    XCTAssertNotNil(rs);
    XCTAssertTrue([rs next]);
    
    XCTAssertEqualObjects([rs stringForColumn:@"b"], @"Text2");
    
    [rs close];
}

- (void)testPragmaDatabaseList
{
    FMResultSet *rs = [self.db executeQuery:@"pragma database_list"];
    int counter = 0;
    while ([rs next]) {
        counter++;
        XCTAssertEqualObjects([rs stringForColumn:@"file"], self.databasePath);
    }
    XCTAssertEqual(counter, 1, @"Only one database should be attached");
}

- (void)testCachedStatementsInUse
{
    [self.db setShouldCacheStatements:true];
    
    [self.db executeUpdate:@"CREATE TABLE testCacheStatements(key INTEGER PRIMARY KEY, value INTEGER)"];
    [self.db executeUpdate:@"INSERT INTO testCacheStatements (key, value) VALUES (1, 2)"];
    [self.db executeUpdate:@"INSERT INTO testCacheStatements (key, value) VALUES (2, 4)"];
    
    XCTAssertTrue([[self.db executeQuery:@"SELECT * FROM testCacheStatements WHERE key=1"] next]);
    XCTAssertTrue([[self.db executeQuery:@"SELECT * FROM testCacheStatements WHERE key=1"] next]);
}

- (void)testStatementCachingWorks
{
    [self.db executeUpdate:@"CREATE TABLE testStatementCaching ( value INTEGER )"];
    [self.db executeUpdate:@"INSERT INTO testStatementCaching( value ) VALUES (1)"];
    [self.db executeUpdate:@"INSERT INTO testStatementCaching( value ) VALUES (1)"];
    [self.db executeUpdate:@"INSERT INTO testStatementCaching( value ) VALUES (2)"];
    
    [self.db setShouldCacheStatements:YES];
    
    // two iterations.
    //  the first time through no statements will be from the cache.
    //  the second time through all statements come from the cache.
    for (int i = 1; i <= 2; i++ ) {
        
        FMResultSet* rs1 = [self.db executeQuery: @"SELECT rowid, * FROM testStatementCaching WHERE value = ?", @1]; // results in 2 rows...
        XCTAssertNotNil(rs1);
        XCTAssertTrue([rs1 next]);
        
        // confirm that we're seeing the benefits of caching.
        XCTAssertEqual([[rs1 statement] useCount], (long)i);
        
        FMResultSet* rs2 = [self.db executeQuery:@"SELECT rowid, * FROM testStatementCaching WHERE value = ?", @2]; // results in 1 row
        XCTAssertNotNil(rs2);
        XCTAssertTrue([rs2 next]);
        XCTAssertEqual([[rs2 statement] useCount], (long)i);
        
        // This is the primary check - with the old implementation of statement caching, rs2 would have rejiggered the (cached) statement used by rs1, making this test fail to return the 2nd row in rs1.
        XCTAssertTrue([rs1 next]);
        
        [rs1 close];
        [rs2 close];
    }
    
}

/*
 Test the date format
 */

- (void)testDateFormat
{
    void (^testOneDateFormat)(FMDatabase *, NSDate *) = ^( FMDatabase *db, NSDate *testDate ){
        [db executeUpdate:@"DROP TABLE IF EXISTS test_format"];
        [db executeUpdate:@"CREATE TABLE test_format ( test TEXT )"];
        [db executeUpdate:@"INSERT INTO test_format(test) VALUES (?)", testDate];
        
        FMResultSet *rs = [db executeQuery:@"SELECT test FROM test_format"];
        XCTAssertNotNil(rs);
        XCTAssertTrue([rs next]);
        
        XCTAssertEqualObjects([rs dateForColumnIndex:0], testDate);

        [rs close];
    };
    
    NSDateFormatter *fmt = [FMDatabase storeableDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    NSDate *testDate = [fmt dateFromString:@"2013-02-20 12:00:00"];
    
    // test timestamp dates (ensuring our change does not break those)
    testOneDateFormat(self.db,testDate);
    
    // now test the string-based timestamp
    [self.db setDateFormat:fmt];
    testOneDateFormat(self.db, testDate);
}

- (void)testColumnNameMap
{
    XCTAssertTrue([self.db executeUpdate:@"create table colNameTest (a, b, c, d)"]);
    XCTAssertTrue([self.db executeUpdate:@"insert into colNameTest values (1, 2, 3, 4)"]);
    
    FMResultSet *ars = [self.db executeQuery:@"select * from colNameTest"];
    XCTAssertNotNil(ars);
    
    NSDictionary *d = [ars columnNameToIndexMap];
    XCTAssertEqual([d count], (NSUInteger)4);
    
    XCTAssertEqualObjects([d objectForKey:@"a"], @0);
    XCTAssertEqualObjects([d objectForKey:@"b"], @1);
    XCTAssertEqualObjects([d objectForKey:@"c"], @2);
    XCTAssertEqualObjects([d objectForKey:@"d"], @3);
    
}

- (void)testCustomStringFunction {
    [self createCustomFunctions];
    
    FMResultSet *ars = [self.db executeQuery:@"SELECT RemoveDiacritics(?)", @"José"];
    if (![ars next]) {
        XCTFail("Should have returned value");
        return;
    }
    NSString *result = [ars stringForColumnIndex:0];
    XCTAssertEqualObjects(result, @"Jose");
}

- (void)testFailCustomStringFunction {
    [self createCustomFunctions];
    
    FMResultSet *rs = [self.db executeQuery:@"SELECT RemoveDiacritics(?)", @(M_PI)];
    XCTAssert(rs, @"Prepare should have succeeded");
    
    NSError *error;
    BOOL success = [rs nextWithError:&error];
    XCTAssertFalse(success, @"'next' should have failed");
    
    XCTAssertEqualObjects(error.localizedDescription, @"Expected text");

    rs = [self.db executeQuery:@"SELECT RemoveDiacritics('jose','ortega')"];
    XCTAssertNil(rs);

    error = [self.db lastError];

    XCTAssert([error.localizedDescription containsString:@"wrong number of arguments"], @"Should get wrong number of arguments error, but got '%@'", error.localizedDescription);
}

- (void)testCustomDoubleFunction {
    [self createCustomFunctions];
    
    FMResultSet *rs = [self.db executeQuery:@"SELECT Hypotenuse(?, ?)", @(3.0), @(4.0)];
    if (![rs next]) {
        XCTFail("Should have returned value");
        return;
    }
    double value = [rs doubleForColumnIndex:0];
    XCTAssertEqual(value, 5.0);
}

- (void)testCustomIntFunction {
    [self createCustomFunctions];
    
    FMResultSet *rs = [self.db executeQuery:@"SELECT Hypotenuse(?, ?)", @(3), @(4)];
    if (![rs next]) {
        XCTFail("Should have returned value");
        return;
    }
    int value = [rs intForColumnIndex:0];
    XCTAssertEqual(value, 5);
}

- (void)testFailCustomNumericFunction {
    [self createCustomFunctions];
    
    FMResultSet *rs = [self.db executeQuery:@"SELECT Hypotenuse(?, ?)", @"foo", @"bar"];
    NSError *error;
    if ([rs nextWithError:&error]) {
        XCTFail("Should have failed");
        return;
    }
    XCTAssertEqualObjects(error.localizedDescription, @"Expected numeric");
    
    rs = [self.db executeQuery:@"SELECT Hypotenuse(?)", @(3.0)];
    XCTAssertNil(rs, @"Should fail for wrong number of arguments");

    error = [self.db lastError];
    XCTAssert([error.localizedDescription containsString:@"wrong number of arguments"], @"Should get wrong number of arguments error, but got '%@'", error.localizedDescription);
}

- (void)testCustomDataFunction {
    [self createCustomFunctions];
    
    NSMutableData *data = [NSMutableData data];
    for (NSInteger i = 0; i < 256; i++) {
        uint8_t byte = i;
        [data appendBytes:&byte length:1];
    }
    
    FMResultSet *rs = [self.db executeQuery:@"SELECT SetAlternatingByteToOne(?)", data];
    if (![rs next]) {
        XCTFail("Should have returned value");
        return;
    }
    NSData *result = [rs dataForColumnIndex:0];
    XCTAssert(result, @"should have result");
    XCTAssertEqual(result.length, (unsigned long)256);
    
    for (NSInteger i = 0; i < 256; i++) {
        uint8_t byte;
        [result getBytes:&byte range:NSMakeRange(i, 1)];
        if (i % 2 == 0) {
            XCTAssertEqual(byte, (uint8_t)1);
        } else {
            XCTAssertEqual(byte, (uint8_t)i);
        }
    }
}

- (void)testFailCustomDataFunction {
    [self createCustomFunctions];
    
    FMResultSet *rs = [self.db executeQuery:@"SELECT SetAlternatingByteToOne(?)", @"foo"];
    XCTAssert(rs, @"Query should succeed");
    NSError *error;
    BOOL success = [rs nextWithError:&error];
    XCTAssertFalse(success, @"Performing SetAlternatingByteToOne with string should fail");
    XCTAssertEqualObjects(error.localizedDescription, @"Expected blob");
}

- (void)testCustomFunctionNullValues {
    [self.db makeFunctionNamed:@"FunctionThatDoesntTestTypes" arguments:1 block:^(void *context, int argc, void **argv) {
        NSData *data = [self.db valueData:argv[0]];
        XCTAssertNil(data);
        NSString *string = [self.db valueString:argv[0]];
        XCTAssertNil(string);
        int intValue = [self.db valueInt:argv[0]];
        XCTAssertEqual(intValue, 0);
        long longValue = [self.db valueLong:argv[0]];
        XCTAssertEqual(longValue, 0L);
        double doubleValue = [self.db valueDouble:argv[0]];
        XCTAssertEqual(doubleValue, 0.0);
        
        [self.db resultInt:42 context:context];
    }];
    
    FMResultSet *rs = [self.db executeQuery:@"SELECT FunctionThatDoesntTestTypes(?)", [NSNull null]];
    XCTAssert(rs, @"Creating query should succeed");
    
    NSError *error = nil;
    if (rs) {
        BOOL success = [rs nextWithError:&error];
        XCTAssert(success, @"Performing query should succeed");
    }
}

- (void)testCustomFunctionIntResult {
    [self.db makeFunctionNamed:@"IntResultFunction" arguments:0 block:^(void *context, int argc, void **argv) {
        [self.db resultInt:42 context:context];
    }];
    
    FMResultSet *rs = [self.db executeQuery:@"SELECT IntResultFunction()"];
    XCTAssert(rs, @"Creating query should succeed");
    
    BOOL success = [rs next];
    XCTAssert(success, @"Performing query should succeed");
    
    XCTAssertEqual([rs intForColumnIndex:0], 42);
}

- (void)testCustomFunctionLongResult {
    [self.db makeFunctionNamed:@"LongResultFunction" arguments:0 block:^(void *context, int argc, void **argv) {
        [self.db resultLong:42 context:context];
    }];
    
    FMResultSet *rs = [self.db executeQuery:@"SELECT LongResultFunction()"];
    XCTAssert(rs, @"Creating query should succeed");
    
    BOOL success = [rs next];
    XCTAssert(success, @"Performing query should succeed");
    
    XCTAssertEqual([rs longForColumnIndex:0], (long)42);
}

- (void)testCustomFunctionDoubleResult {
    [self.db makeFunctionNamed:@"DoubleResultFunction" arguments:0 block:^(void *context, int argc, void **argv) {
        [self.db resultDouble:0.1 context:context];
    }];
    
    FMResultSet *rs = [self.db executeQuery:@"SELECT DoubleResultFunction()"];
    XCTAssert(rs, @"Creating query should succeed");
    
    BOOL success = [rs next];
    XCTAssert(success, @"Performing query should succeed");
    
    XCTAssertEqual([rs doubleForColumnIndex:0], 0.1);
}

- (void)testCustomFunctionNullResult {
    [self.db makeFunctionNamed:@"NullResultFunction" arguments:0 block:^(void *context, int argc, void **argv) {
        [self.db resultNullInContext:context];
    }];
    
    FMResultSet *rs = [self.db executeQuery:@"SELECT NullResultFunction()"];
    XCTAssert(rs, @"Creating query should succeed");
    
    BOOL success = [rs next];
    XCTAssert(success, @"Performing query should succeed");
    
    XCTAssertEqualObjects([rs objectForColumnIndex:0], [NSNull null]);
}

- (void)testCustomFunctionErrorResult {
    [self.db makeFunctionNamed:@"ErrorResultFunction" arguments:0 block:^(void *context, int argc, void **argv) {
        [self.db resultError:@"foo" context:context];
        [self.db resultErrorCode:42 context:context];
    }];
    
    FMResultSet *rs = [self.db executeQuery:@"SELECT ErrorResultFunction()"];
    XCTAssert(rs, @"Creating query should succeed");
    
    NSError *error = nil;
    BOOL success = [rs nextWithError:&error];
    XCTAssertFalse(success, @"Performing query should fail.");
    
    XCTAssertEqualObjects(error.localizedDescription, @"foo");
    XCTAssertEqual(error.code, 42);
}

- (void)testCustomFunctionTooBigErrorResult {
    [self.db makeFunctionNamed:@"TooBigErrorResultFunction" arguments:0 block:^(void *context, int argc, void **argv) {
        [self.db resultErrorTooBigInContext:context];
    }];
    
    FMResultSet *rs = [self.db executeQuery:@"SELECT TooBigErrorResultFunction()"];
    XCTAssert(rs, @"Creating query should succeed");
    
    NSError *error = nil;
    BOOL success = [rs nextWithError:&error];
    XCTAssertFalse(success, @"Performing query should fail.");
    
    XCTAssertEqualObjects(error.localizedDescription, @"string or blob too big");
    XCTAssertEqual(error.code, SQLITE_TOOBIG);
}

- (void)testCustomFunctionNoMemoryErrorResult {
    [self.db makeFunctionNamed:@"NoMemoryErrorResultFunction" arguments:0 block:^(void *context, int argc, void **argv) {
        [self.db resultErrorNoMemoryInContext:context];
    }];
    
    FMResultSet *rs = [self.db executeQuery:@"SELECT NoMemoryErrorResultFunction()"];
    XCTAssert(rs, @"Creating query should succeed");
    
    NSError *error = nil;
    BOOL success = [rs nextWithError:&error];
    XCTAssertFalse(success, @"Performing query should fail.");
    
    XCTAssertEqualObjects(error.localizedDescription, @"out of memory");
    XCTAssertEqual(error.code, SQLITE_NOMEM);
}

- (void)createCustomFunctions {
    [self.db makeFunctionNamed:@"RemoveDiacritics" arguments:1 block:^(void *context, int argc, void **argv) {
        SqliteValueType type = [self.db valueType:argv[0]];
        if (type == SqliteValueTypeNull) {
            [self.db resultNullInContext:context];
            return;
        }
        if (type != SqliteValueTypeText) {
            [self.db resultError:@"Expected text" context:context];
            return;
        }
        NSString *string = [self.db valueString:argv[0]];
        NSString *result = [string stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:nil];
        [self.db resultString:result context:context];
    }];

    [self.db makeFunctionNamed:@"Hypotenuse" arguments:2 block:^(void *context, int argc, void **argv) {
        SqliteValueType type1 = [self.db valueType:argv[0]];
        SqliteValueType type2 = [self.db valueType:argv[1]];
        if (type1 != SqliteValueTypeFloat && type1 != SqliteValueTypeInteger && type2 != SqliteValueTypeFloat && type2 != SqliteValueTypeInteger) {
            [self.db resultError:@"Expected numeric" context:context];
            return;
        }
        double value1 = [self.db valueDouble:argv[0]];
        double value2 = [self.db valueDouble:argv[1]];
        [self.db resultDouble:hypot(value1, value2) context:context];
    }];

    [self.db makeFunctionNamed:@"SetAlternatingByteToOne" arguments:1 block:^(void *context, int argc, void **argv) {
        SqliteValueType type = [self.db valueType:argv[0]];
        if (type != SqliteValueTypeBlob) {
            [self.db resultError:@"Expected blob" context:context];
            return;
        }
        NSMutableData *data = [[self.db valueData:argv[0]] mutableCopy];
        uint8_t byte = 1;
        for (NSUInteger i = 0; i < data.length; i += 2) {
            [data replaceBytesInRange:NSMakeRange(i, 1) withBytes:&byte];
        }
        [self.db resultData:data context:context];
    }];

}

- (void)testVersionNumber {
    XCTAssertTrue([FMDatabase FMDBVersion] == 0x0272); // this is going to break everytime we bump it.
}

- (void)testExecuteStatements {
    BOOL success;

    NSString *sql = @"create table bulktest1 (id integer primary key autoincrement, x text);"
                     "create table bulktest2 (id integer primary key autoincrement, y text);"
                     "create table bulktest3 (id integer primary key autoincrement, z text);"
                     "insert into bulktest1 (x) values ('XXX');"
                     "insert into bulktest2 (y) values ('YYY');"
                     "insert into bulktest3 (z) values ('ZZZ');";

    success = [self.db executeStatements:sql];

    XCTAssertTrue(success, @"bulk create");

    sql = @"select count(*) as count from bulktest1;"
           "select count(*) as count from bulktest2;"
           "select count(*) as count from bulktest3;";

    success = [self.db executeStatements:sql withResultBlock:^int(NSDictionary *dictionary) {
        NSInteger count = [dictionary[@"count"] integerValue];
        XCTAssertEqual(count, 1, @"expected one record for dictionary %@", dictionary);
        return 0;
    }];

    XCTAssertTrue(success, @"bulk select");

    sql = @"drop table bulktest1;"
           "drop table bulktest2;"
           "drop table bulktest3;";

    success = [self.db executeStatements:sql];

    XCTAssertTrue(success, @"bulk drop");
}

- (void)testCharAndBoolTypes
{
    XCTAssertTrue([self.db executeUpdate:@"create table charBoolTest (a, b, c)"]);

    BOOL success = [self.db executeUpdate:@"insert into charBoolTest values (?, ?, ?)", @YES, @NO, @('x')];
    XCTAssertTrue(success, @"Unable to insert values");

    FMResultSet *rs = [self.db executeQuery:@"select * from charBoolTest"];
    XCTAssertNotNil(rs);

    XCTAssertTrue([rs next], @"Did not return row");

    XCTAssertEqual([rs boolForColumn:@"a"], true);
    XCTAssertEqualObjects([rs objectForColumn:@"a"], @YES);

    XCTAssertEqual([rs boolForColumn:@"b"], false);
    XCTAssertEqualObjects([rs objectForColumn:@"b"], @NO);

    XCTAssertEqual([rs intForColumn:@"c"], 'x');
    XCTAssertEqualObjects([rs objectForColumn:@"c"], @('x'));

    [rs close];

    XCTAssertTrue([self.db executeUpdate:@"drop table charBoolTest"], @"Did not drop table");

}

- (void)testSqliteLibVersion
{
    NSString *version = [FMDatabase sqliteLibVersion];
    XCTAssert([version compare:@"3.7" options:NSNumericSearch] == NSOrderedDescending, @"earlier than 3.7");
    XCTAssert([version compare:@"4.0" options:NSNumericSearch] == NSOrderedAscending, @"not earlier than 4.0");
}

- (void)testIsThreadSafe
{
    BOOL isThreadSafe = [FMDatabase isSQLiteThreadSafe];
    XCTAssert(isThreadSafe, @"not threadsafe");
}

- (void)testOpenNilPath
{
    FMDatabase *db = [[FMDatabase alloc] init];
    XCTAssert([db open], @"open failed");
    XCTAssert([db executeUpdate:@"create table foo (bar text)"], @"create failed");
    NSString *value = @"baz";
    XCTAssert([db executeUpdate:@"insert into foo (bar) values (?)" withArgumentsInArray:@[value]], @"insert failed");
    NSString *retrievedValue = [db stringForQuery:@"select bar from foo"];
    XCTAssert([value compare:retrievedValue] == NSOrderedSame, @"values didn't match");
}

- (void)testOpenZeroLengthPath
{
    FMDatabase *db = [[FMDatabase alloc] initWithPath:@""];
    XCTAssert([db open], @"open failed");
    XCTAssert([db executeUpdate:@"create table foo (bar text)"], @"create failed");
    NSString *value = @"baz";
    XCTAssert([db executeUpdate:@"insert into foo (bar) values (?)" withArgumentsInArray:@[value]], @"insert failed");
    NSString *retrievedValue = [db stringForQuery:@"select bar from foo"];
    XCTAssert([value compare:retrievedValue] == NSOrderedSame, @"values didn't match");
}

- (void)testOpenTwice
{
    FMDatabase *db = [[FMDatabase alloc] init];
    [db open];
    XCTAssert([db open], @"Double open failed");
}

- (void)testInvalid
{
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *path          = [documentsPath stringByAppendingPathComponent:@"nonexistentfolder/test.sqlite"];

    FMDatabase *db = [[FMDatabase alloc] initWithPath:path];
    XCTAssertFalse([db open], @"open did NOT fail");
}

- (void)testChangingMaxBusyRetryTimeInterval
{
    FMDatabase *db = [[FMDatabase alloc] init];
    XCTAssert([db open], @"open failed");

    NSTimeInterval originalInterval = db.maxBusyRetryTimeInterval;
    NSTimeInterval updatedInterval = originalInterval > 0 ? originalInterval + 1 : 1;
    
    db.maxBusyRetryTimeInterval = updatedInterval;
    NSTimeInterval diff = fabs(db.maxBusyRetryTimeInterval - updatedInterval);
    
    XCTAssert(diff < 1e-5, @"interval should have changed %.1f", diff);
}

- (void)testChangingMaxBusyRetryTimeIntervalDatabaseNotOpened
{
    FMDatabase *db = [[FMDatabase alloc] init];
    // XCTAssert([db open], @"open failed");   // deliberately not opened

    NSTimeInterval originalInterval = db.maxBusyRetryTimeInterval;
    NSTimeInterval updatedInterval = originalInterval > 0 ? originalInterval + 1 : 1;
    
    db.maxBusyRetryTimeInterval = updatedInterval;
    XCTAssertNotEqual(originalInterval, db.maxBusyRetryTimeInterval, @"interval should not have changed");
}

- (void)testZeroMaxBusyRetryTimeInterval
{
    FMDatabase *db = [[FMDatabase alloc] init];
    XCTAssert([db open], @"open failed");
    
    NSTimeInterval updatedInterval = 0;
    
    db.maxBusyRetryTimeInterval = updatedInterval;
    XCTAssertEqual(db.maxBusyRetryTimeInterval, updatedInterval, @"busy handler not disabled");
}

- (void)testCloseOpenResultSets
{
    FMDatabase *db = [[FMDatabase alloc] init];
    XCTAssert([db open], @"open failed");
    XCTAssert([db executeUpdate:@"create table foo (bar text)"], @"create failed");
    NSString *value = @"baz";
    XCTAssert([db executeUpdate:@"insert into foo (bar) values (?)" withArgumentsInArray:@[value]], @"insert failed");
    FMResultSet *rs = [db executeQuery:@"select bar from foo"];
    [db closeOpenResultSets];
    XCTAssertFalse([rs next], @"step should have failed");
}

- (void)testGoodConnection
{
    FMDatabase *db = [[FMDatabase alloc] init];
    XCTAssert([db open], @"open failed");
    XCTAssert([db goodConnection], @"no good connection");
}

- (void)testBadConnection
{
    FMDatabase *db = [[FMDatabase alloc] init];
    // XCTAssert([db open], @"open failed");  // deliberately did not open
    XCTAssertFalse([db goodConnection], @"no good connection");
}

- (void)testLastRowId
{
    FMDatabase *db = [[FMDatabase alloc] init];
    XCTAssert([db open], @"open failed");
    XCTAssert([db executeUpdate:@"create table foo (foo_id integer primary key autoincrement, bar text)"], @"create failed");
    
    XCTAssert([db executeUpdate:@"insert into foo (bar) values (?)" withArgumentsInArray:@[@"baz"]], @"insert failed");
    sqlite3_int64 firstRowId = [db lastInsertRowId];
    
    XCTAssert([db executeUpdate:@"insert into foo (bar) values (?)" withArgumentsInArray:@[@"qux"]], @"insert failed");
    sqlite3_int64 secondRowId = [db lastInsertRowId];
    
    XCTAssertEqual(secondRowId - firstRowId, 1, @"rowid should have incremented");
}

- (void)testChanges
{
    FMDatabase *db = [[FMDatabase alloc] init];
    XCTAssert([db open], @"open failed");
    XCTAssert([db executeUpdate:@"create table foo (foo_id integer primary key autoincrement, bar text)"], @"create failed");
    
    XCTAssert([db executeUpdate:@"insert into foo (bar) values (?)" withArgumentsInArray:@[@"baz"]], @"insert failed");
    XCTAssert([db executeUpdate:@"insert into foo (bar) values (?)" withArgumentsInArray:@[@"qux"]], @"insert failed");
    XCTAssert([db executeUpdate:@"update foo set bar = ?" withArgumentsInArray:@[@"xxx"]], @"insert failed");
    int changes = [db changes];
    
    XCTAssertEqual(changes, 2, @"two rows should have incremented \(%ld)", (long)changes);
}

- (void)testBind {
    FMDatabase *db = [[FMDatabase alloc] init];
    XCTAssert([db open], @"open failed");
    XCTAssert([db executeUpdate:@"create table foo (id integer primary key autoincrement, a numeric)"], @"create failed");
    
    NSNumber *insertedValue;
    NSNumber *retrievedValue;
    
    insertedValue = [NSNumber numberWithChar:51];
    XCTAssert([db executeUpdate:@"insert into foo (a) values (?)" withArgumentsInArray:@[insertedValue]], @"insert failed");
    retrievedValue = @([db intForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])]);
    XCTAssertEqualObjects(insertedValue, retrievedValue, @"values don't match");
    
    insertedValue = [NSNumber numberWithUnsignedChar:52];
    XCTAssert([db executeUpdate:@"insert into foo (a) values (?)" withArgumentsInArray:@[insertedValue]], @"insert failed");
    retrievedValue = @([db intForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])]);
    XCTAssertEqualObjects(insertedValue, retrievedValue, @"values don't match");

    insertedValue = [NSNumber numberWithShort:53];
    XCTAssert([db executeUpdate:@"insert into foo (a) values (?)" withArgumentsInArray:@[insertedValue]], @"insert failed");
    retrievedValue = @([db intForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])]);
    XCTAssertEqualObjects(insertedValue, retrievedValue, @"values don't match");
    
    insertedValue = [NSNumber numberWithUnsignedShort:54];
    XCTAssert([db executeUpdate:@"insert into foo (a) values (?)" withArgumentsInArray:@[insertedValue]], @"insert failed");
    retrievedValue = @([db intForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])]);
    XCTAssertEqualObjects(insertedValue, retrievedValue, @"values don't match");
    
    insertedValue = [NSNumber numberWithInt:54];
    XCTAssert([db executeUpdate:@"insert into foo (a) values (?)" withArgumentsInArray:@[insertedValue]], @"insert failed");
    retrievedValue = @([db intForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])]);
    XCTAssertEqualObjects(insertedValue, retrievedValue, @"values don't match");
    
    insertedValue = [NSNumber numberWithUnsignedInt:55];
    XCTAssert([db executeUpdate:@"insert into foo (a) values (?)" withArgumentsInArray:@[insertedValue]], @"insert failed");
    retrievedValue = @([db intForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])]);
    XCTAssertEqualObjects(insertedValue, retrievedValue, @"values don't match");
    
    insertedValue = [NSNumber numberWithLong:56];
    XCTAssert([db executeUpdate:@"insert into foo (a) values (?)" withArgumentsInArray:@[insertedValue]], @"insert failed");
    retrievedValue = @([db longForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])]);
    XCTAssertEqualObjects(insertedValue, retrievedValue, @"values don't match");
    
    insertedValue = [NSNumber numberWithUnsignedLong:57];
    XCTAssert([db executeUpdate:@"insert into foo (a) values (?)" withArgumentsInArray:@[insertedValue]], @"insert failed");
    retrievedValue = @([db longForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])]);
    XCTAssertEqualObjects(insertedValue, retrievedValue, @"values don't match");
    
    insertedValue = [NSNumber numberWithLongLong:56];
    XCTAssert([db executeUpdate:@"insert into foo (a) values (?)" withArgumentsInArray:@[insertedValue]], @"insert failed");
    retrievedValue = @([db longForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])]);
    XCTAssertEqualObjects(insertedValue, retrievedValue, @"values don't match");
    
    insertedValue = [NSNumber numberWithUnsignedLongLong:57];
    XCTAssert([db executeUpdate:@"insert into foo (a) values (?)" withArgumentsInArray:@[insertedValue]], @"insert failed");
    retrievedValue = @([db longForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])]);
    XCTAssertEqualObjects(insertedValue, retrievedValue, @"values don't match");
    
    insertedValue = [NSNumber numberWithFloat:58];
    XCTAssert([db executeUpdate:@"insert into foo (a) values (?)" withArgumentsInArray:@[insertedValue]], @"insert failed");
    retrievedValue = @([db doubleForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])]);
    XCTAssertEqualObjects(insertedValue, retrievedValue, @"values don't match");
    
    insertedValue = [NSNumber numberWithDouble:59];
    XCTAssert([db executeUpdate:@"insert into foo (a) values (?)" withArgumentsInArray:@[insertedValue]], @"insert failed");
    retrievedValue = @([db doubleForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])]);
    XCTAssertEqualObjects(insertedValue, retrievedValue, @"values don't match");

    insertedValue = @TRUE;
    XCTAssert([db executeUpdate:@"insert into foo (a) values (?)" withArgumentsInArray:@[insertedValue]], @"insert failed");
    retrievedValue = @([db boolForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])]);
    XCTAssertEqualObjects(insertedValue, retrievedValue, @"values don't match");
}

- (void)testFormatStrings {
    FMDatabase *db = [[FMDatabase alloc] init];
    XCTAssert([db open], @"open failed");
    XCTAssert([db executeUpdate:@"create table foo (id integer primary key autoincrement, a numeric)"], @"create failed");
    
    BOOL success;
    
    char insertedChar = 'A';
    success = [db executeUpdateWithFormat:@"insert into foo (a) values (%c)", insertedChar];
    XCTAssert(success, @"insert failed");
    const char *retrievedChar = [[db stringForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])] UTF8String];
    XCTAssertEqual(insertedChar, retrievedChar[0], @"values don't match");
    
    const char *insertedString = "baz";
    success = [db executeUpdateWithFormat:@"insert into foo (a) values (%s)", insertedString];
    XCTAssert(success, @"insert failed");
    const char *retrievedString = [[db stringForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])] UTF8String];
    XCTAssert(strcmp(insertedString, retrievedString) == 0, @"values don't match");
    
    int insertedInt = 42;
    success = [db executeUpdateWithFormat:@"insert into foo (a) values (%d)", insertedInt];
    XCTAssert(success, @"insert failed");
    int retrievedInt = [db intForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])];
    XCTAssertEqual(insertedInt, retrievedInt, @"values don't match");

    char insertedUnsignedInt = 43;
    success = [db executeUpdateWithFormat:@"insert into foo (a) values (%u)", insertedUnsignedInt];
    XCTAssert(success, @"insert failed");
    char retrievedUnsignedInt = [db intForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])];
    XCTAssertEqual(insertedUnsignedInt, retrievedUnsignedInt, @"values don't match");
    
    float insertedFloat = 44;
    success = [db executeUpdateWithFormat:@"insert into foo (a) values (%f)", insertedFloat];
    XCTAssert(success, @"insert failed");
    float retrievedFloat = [db doubleForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])];
    XCTAssertEqual(insertedFloat, retrievedFloat, @"values don't match");
    
    unsigned long long insertedUnsignedLongLong = 45;
    success = [db executeUpdateWithFormat:@"insert into foo (a) values (%llu)", insertedUnsignedLongLong];
    XCTAssert(success, @"insert failed");
    unsigned long long retrievedUnsignedLongLong = [db longForQuery:@"select a from foo where id = ?", @([db lastInsertRowId])];
    XCTAssertEqual(insertedUnsignedLongLong, retrievedUnsignedLongLong, @"values don't match");
}

- (void)testStepError {
    FMDatabase *db = [[FMDatabase alloc] init];
    XCTAssert([db open], @"open failed");
    XCTAssert([db executeUpdate:@"create table foo (id integer primary key)"], @"create failed");
    XCTAssert([db executeUpdate:@"insert into foo (id) values (?)" values:@[@1] error:nil], @"create failed");
    
    NSError *error;
    BOOL success = [db executeUpdate:@"insert into foo (id) values (?)" values:@[@1] error:&error];
    XCTAssertFalse(success, @"insert of duplicate key should have failed");
    XCTAssertNotNil(error, @"error object should have been generated");
    XCTAssertEqual(error.code, 19, @"error code 19 should have been generated");
}

@end
