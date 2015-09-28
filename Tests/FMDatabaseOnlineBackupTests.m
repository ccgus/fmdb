//
//  FMDatabaseOnlineBackupTests.m
//  fmdb
//
//  Created by Mark Pustjens <pustjens@dds.nl> on 23/09/15.
//  (c) Angelbird Technologies GmbH
//
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

@interface FMDatabaseOnlineBackupTests : FMDBTempDBTests

@end

@implementation FMDatabaseOnlineBackupTests

+ (void)populateDatabase:(FMDatabase *)db
{
	[db executeUpdate:@"create table test (a text, b text, c integer, d double, e double)"];
	
	[db beginTransaction];
	int i = 0;
	while (i++ < 2000) {
		[db executeUpdate:@"insert into test (a, b, c, d, e) values (?, ?, ?, ?, ?)" ,
		 @"hi'", // look!  I put in a ', and I'm not escaping it!
		 [NSString stringWithFormat:@"number %d", i],
		 [NSNumber numberWithInt:i],
		 [NSDate date],
		 [NSNumber numberWithFloat:2.2f]];
	}
	[db commit];
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testBackupDatabase
{
	NSString *backupPath = @"/tmp/tmp.db.bck";

	// perform the backup
	XCTAssertTrue ([self.db backupTo:backupPath withKey:nil andProgressBlock:^(int pagesRemaining, int pageCount) {
		// No need to show progress.
	}], @"Should have succeeded");
	
	// check if the backup file exists
	NSFileManager *fileManager = [NSFileManager defaultManager];
	XCTAssertTrue([fileManager fileExistsAtPath:backupPath],
				  @"Backup db file should exist");
	
	// test if the bakcup is ok
	FMDatabase *bck = [FMDatabase databaseWithPath:backupPath];
	XCTAssertTrue([bck open], @"Should pass");
	XCTAssert([bck executeQuery:@"select * from test"] != nil, @"Should pass");
	XCTAssertTrue([bck close], @"Should pass");
	
	// delete backup
	[fileManager removeItemAtPath:backupPath error:NULL];
}

- (void)testBackupDatabaseEncrypted
{
	NSString *backupPath = @"/tmp/tmp.edb.bck";
	
	// perform the backup
	XCTAssertTrue ([self.db backupTo:backupPath withKey:@"passw0rd" andProgressBlock:^(int pagesRemaining, int pageCount) {
		// No need to show progress.
	}], @"Should have succeeded");
	
	// check if the backup file exists
	NSFileManager *fileManager = [NSFileManager defaultManager];
	XCTAssertTrue([fileManager fileExistsAtPath:backupPath],
				  @"Backup db file should exist");
	
	// test if the backup is ok
	FMDatabase *bck = [FMDatabase databaseWithPath:backupPath];
	XCTAssertTrue([bck open], @"Should pass");
	XCTAssert([bck executeQuery:@"select * from test"] != nil, @"Should pass");
	XCTAssertTrue([bck close], @"Should pass");
	
	// delete backup
	[fileManager removeItemAtPath:backupPath error:NULL];
}

@end
