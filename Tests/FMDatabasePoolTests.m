//
//  FMDatabasePoolTests.m
//  fmdb
//
//  Created by Graham Dennis on 24/11/2013.
//
//

#import <XCTest/XCTest.h>

#if FMDB_SQLITE_STANDALONE
#import <sqlite3/sqlite3.h>
#else
#import <sqlite3.h>
#endif

@interface FMDatabasePoolTests : FMDBTempDBTests

@property FMDatabasePool *pool;

@end

@implementation FMDatabasePoolTests

+ (void)populateDatabase:(FMDatabase *)db
{
    [db executeUpdate:@"create table easy (a text)"];
    [db executeUpdate:@"create table easy2 (a text)"];

    [db executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1001]];
    [db executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1002]];
    [db executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1003]];

    [db executeUpdate:@"create table likefoo (foo text)"];
    [db executeUpdate:@"insert into likefoo values ('hi')"];
    [db executeUpdate:@"insert into likefoo values ('hello')"];
    [db executeUpdate:@"insert into likefoo values ('not')"];
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    [self setPool:[FMDatabasePool databasePoolWithPath:self.databasePath]];
    
    [[self pool] setDelegate:self];
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testURLOpenNoURL {
    FMDatabasePool *pool = [[FMDatabasePool alloc] initWithURL:nil];
    XCTAssert(pool, @"Database pool should be returned");
    pool = nil;
}

- (void)testURLOpen {
    NSURL *tempFolder = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *fileURL = [tempFolder URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    
    FMDatabasePool *pool = [FMDatabasePool databasePoolWithURL:fileURL];
    XCTAssert(pool, @"Database pool should be returned");
    pool = nil;
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
}

- (void)testURLOpenInit {
    NSURL *tempFolder = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *fileURL = [tempFolder URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    
    FMDatabasePool *pool = [[FMDatabasePool alloc] initWithURL:fileURL];
    XCTAssert(pool, @"Database pool should be returned");
    pool = nil;
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
}

- (void)testURLOpenWithOptions {
    NSURL *tempFolder = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *fileURL = [tempFolder URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    
    FMDatabasePool *pool = [FMDatabasePool databasePoolWithURL:fileURL flags:SQLITE_OPEN_READWRITE];
    [pool inDatabase:^(FMDatabase * _Nonnull db) {
        XCTAssertNil(db, @"The database should not have been created");
    }];
}

- (void)testURLOpenInitWithOptions {
    NSURL *tempFolder = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *fileURL = [tempFolder URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    
    FMDatabasePool *pool = [[FMDatabasePool alloc] initWithURL:fileURL flags:SQLITE_OPEN_READWRITE];
    [pool inDatabase:^(FMDatabase * _Nonnull db) {
        XCTAssertNil(db, @"The database should not have been created");
    }];
    
    pool = [[FMDatabasePool alloc] initWithURL:fileURL flags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE];
    [pool inDatabase:^(FMDatabase * _Nonnull db) {
        XCTAssert(db, @"The database should have been created");

        BOOL success = [db executeUpdate:@"CREATE TABLE foo (bar INT)"];
        XCTAssert(success, @"Create failed");
        success = [db executeUpdate:@"INSERT INTO foo (bar) VALUES (?)", @42];
        XCTAssert(success, @"Insert failed");
    }];
    
    pool = [[FMDatabasePool alloc] initWithURL:fileURL flags:SQLITE_OPEN_READONLY];
    [pool inDatabase:^(FMDatabase * _Nonnull db) {
        XCTAssert(db, @"Now database pool should open have been created");
        BOOL success = [db executeUpdate:@"CREATE TABLE baz (qux INT)"];
        XCTAssertFalse(success, @"But updates should fail on read only database");
    }];
    pool = nil;
    
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
}

- (void)testURLOpenWithOptionsVfs {
    sqlite3_vfs vfs = *sqlite3_vfs_find(NULL);
    vfs.zName = "MyCustomVFS";
    XCTAssertEqual(SQLITE_OK, sqlite3_vfs_register(&vfs, 0));
    
    NSURL *tempFolder = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *fileURL = [tempFolder URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    
    FMDatabasePool *pool = [[FMDatabasePool alloc] initWithURL:fileURL flags:SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE vfs:@"MyCustomVFS"];
    XCTAssert(pool, @"Database pool should not have been created");
    pool = nil;
    
    XCTAssertEqual(SQLITE_OK, sqlite3_vfs_unregister(&vfs));
}

- (void)testPoolIsInitiallyEmpty {
    XCTAssertEqual([self.pool countOfOpenDatabases], (NSUInteger)0, @"Pool should be empty on creation");
}

- (void)testDatabaseCreation {
    __block FMDatabase *db1;
    
    [self.pool inDatabase:^(FMDatabase *db) {
        
        XCTAssertEqual([self.pool countOfOpenDatabases], (NSUInteger)1, @"Should only have one database at this point");
        
        db1 = db;
        
    }];
    
    [self.pool inDatabase:^(FMDatabase *db) {
        XCTAssertEqualObjects(db, db1, @"We should get the same database back because there was no need to create a new one");
        
        [self.pool inDatabase:^(FMDatabase *db2) {
            XCTAssertNotEqualObjects(db2, db, @"We should get a different database because the first was in use.");
        }];
        
    }];
    
    XCTAssertEqual([self.pool countOfOpenDatabases], (NSUInteger)2);
    
    [self.pool releaseAllDatabases];

    XCTAssertEqual([self.pool countOfOpenDatabases], (NSUInteger)0, @"We should be back to zero databases again");
}

- (void)testCheckedInCheckoutOutCount
{
    [self.pool inDatabase:^(FMDatabase *aDb) {
        
        XCTAssertEqual([self.pool countOfCheckedInDatabases],   (NSUInteger)0);
        XCTAssertEqual([self.pool countOfCheckedOutDatabases],  (NSUInteger)1);
        
        XCTAssertTrue(([aDb executeUpdate:@"insert into easy (a) values (?)", @"hi"]));
        
        // just for fun.
        FMResultSet *rs = [aDb executeQuery:@"select * from easy"];
        XCTAssertNotNil(rs);
        XCTAssertTrue([rs next]);
        while ([rs next]) { ; } // whatevers.
        
        XCTAssertEqual([self.pool countOfOpenDatabases],        (NSUInteger)1);
        XCTAssertEqual([self.pool countOfCheckedInDatabases],   (NSUInteger)0);
        XCTAssertEqual([self.pool countOfCheckedOutDatabases],  (NSUInteger)1);
    }];
    
    XCTAssertEqual([self.pool countOfOpenDatabases], (NSUInteger)1);
}

- (void)testMaximumDatabaseLimit
{
    [self.pool setMaximumNumberOfDatabasesToCreate:2];
    
    [self.pool inDatabase:^(FMDatabase *db) {
        [self.pool inDatabase:^(FMDatabase *db2) {
            [self.pool inDatabase:^(FMDatabase *db3) {
                XCTAssertEqual([self.pool countOfOpenDatabases], (NSUInteger)2);
                XCTAssertNil(db3, @"The third database must be nil because we have a maximum of 2 databases in the pool");
            }];
            
        }];
    }];
}

- (void)testTransaction
{
    [self.pool inTransaction:^(FMDatabase *adb, BOOL *rollback) {
        [adb executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1001]];
        [adb executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1002]];
        [adb executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1003]];
        
        XCTAssertEqual([self.pool countOfOpenDatabases],        (NSUInteger)1);
        XCTAssertEqual([self.pool countOfCheckedInDatabases],   (NSUInteger)0);
        XCTAssertEqual([self.pool countOfCheckedOutDatabases],  (NSUInteger)1);
    }];

    XCTAssertEqual([self.pool countOfOpenDatabases],        (NSUInteger)1);
    XCTAssertEqual([self.pool countOfCheckedInDatabases],   (NSUInteger)1);
    XCTAssertEqual([self.pool countOfCheckedOutDatabases],  (NSUInteger)0);
}

- (void)testSelect
{
    [self.pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"select * from easy where a = ?", [NSNumber numberWithInt:1001]];
        XCTAssertNotNil(rs);
        XCTAssertTrue ([rs next]);
        XCTAssertFalse([rs next]);
    }];
}

- (void)testTransactionRollback
{
    [self.pool inDeferredTransaction:^(FMDatabase *adb, BOOL *rollback) {
        XCTAssertTrue(([adb executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1004]]));
        XCTAssertTrue(([adb executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1005]]));
        XCTAssertTrue([[adb executeQuery:@"select * from easy where a == '1004'"] next], @"1004 should be in database");
        
        *rollback = YES;
    }];
    
    [self.pool inDatabase:^(FMDatabase *db) {
        XCTAssertFalse([[db executeQuery:@"select * from easy where a == '1004'"] next], @"1004 should not be in database");
    }];

    XCTAssertEqual([self.pool countOfOpenDatabases],        (NSUInteger)1);
    XCTAssertEqual([self.pool countOfCheckedInDatabases],   (NSUInteger)1);
    XCTAssertEqual([self.pool countOfCheckedOutDatabases],  (NSUInteger)0);
}

- (void)testSavepoint
{
    NSError *err = [self.pool inSavePoint:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1006]];
    }];
    
    XCTAssertNil(err);
}

- (void)testNestedSavepointRollback
{
    NSError *err = [self.pool inSavePoint:^(FMDatabase *adb, BOOL *rollback) {
        XCTAssertFalse([adb hadError]);
        XCTAssertTrue(([adb executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1009]]));
        
        [adb inSavePoint:^(BOOL *arollback) {
            XCTAssertTrue(([adb executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1010]]));
            *arollback = YES;
        }];
    }];
    
    
    XCTAssertNil(err);
    
    [self.pool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"select * from easy where a = ?", [NSNumber numberWithInt:1009]];
        XCTAssertTrue ([rs next]);
        XCTAssertFalse([rs next]); // close it out.
        
        rs = [db executeQuery:@"select * from easy where a = ?", [NSNumber numberWithInt:1010]];
        XCTAssertFalse([rs next]);
    }];
}

- (void)testLikeStringQuery
{
    [self.pool inDatabase:^(FMDatabase *db) {
        int count = 0;
        FMResultSet *rsl = [db executeQuery:@"select * from likefoo where foo like 'h%'"];
        while ([rsl next]) {
            count++;
        }
        
        XCTAssertEqual(count, 2);
        
        count = 0;
        rsl = [db executeQuery:@"select * from likefoo where foo like ?", @"h%"];
        while ([rsl next]) {
            count++;
        }
        
        XCTAssertEqual(count, 2);
        
    }];
}

- (void)testStressTest
{
    size_t ops = 128;
    
    dispatch_queue_t dqueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_apply(ops, dqueue, ^(size_t nby) {
        
        // just mix things up a bit for demonstration purposes.
        if (nby % 2 == 1) {
            
            [NSThread sleepForTimeInterval:.001];
        }
        
        [self.pool inDatabase:^(FMDatabase *db) {
            FMResultSet *rsl = [db executeQuery:@"select * from likefoo where foo like 'h%'"];
            XCTAssertNotNil(rsl);
            int i = 0;
            while ([rsl next]) {
                i++;
                if (nby % 3 == 1) {
                    [NSThread sleepForTimeInterval:.0005];
                }
            }
            XCTAssertEqual(i, 2);
        }];
    });
    
    XCTAssert([self.pool countOfOpenDatabases] < 64, @"There should be significantly less than 64 databases after that stress test");
}


- (BOOL)databasePool:(FMDatabasePool*)pool shouldAddDatabaseToPool:(FMDatabase*)database {
    [database setMaxBusyRetryTimeInterval:10];
    // [database setCrashOnErrors:YES];
    return YES;
}

- (void)testReadWriteStressTest
{
    int ops = 16;
    
    dispatch_queue_t dqueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_apply(ops, dqueue, ^(size_t nby) {
        
        // just mix things up a bit for demonstration purposes.
        if (nby % 2 == 1) {
            [NSThread sleepForTimeInterval:.01];
            
            [self.pool inTransaction:^(FMDatabase *db, BOOL *rollback) {
                FMResultSet *rsl = [db executeQuery:@"select * from likefoo where foo like 'h%'"];
                XCTAssertNotNil(rsl);
                while ([rsl next]) {
                    ;// whatever.
                }
                
            }];
            
        }
        
        if (nby % 3 == 1) {
            [NSThread sleepForTimeInterval:.01];
        }
        
        [self.pool inTransaction:^(FMDatabase *db, BOOL *rollback) {
            XCTAssertTrue([db executeUpdate:@"insert into likefoo values ('1')"]);
            XCTAssertTrue([db executeUpdate:@"insert into likefoo values ('2')"]);
            XCTAssertTrue([db executeUpdate:@"insert into likefoo values ('3')"]);
        }];
    });
    
    [self.pool releaseAllDatabases];
    
    [self.pool inDatabase:^(FMDatabase *db) {
        XCTAssertTrue([db executeUpdate:@"insert into likefoo values ('1')"]);
    }];
}

@end
