//
//  FMDBTempDBTests.m
//  fmdb
//
//  Created by Graham Dennis on 24/11/2013.
//
//

#import "FMDBTempDBTests.h"

static NSString *const testDatabasePath = @"/tmp/tmp.db";
static NSString *const populatedDatabasePath = @"/tmp/tmp-populated.db";

@implementation FMDBTempDBTests

+ (void)setUp
{
    [super setUp];
    
    // Delete old populated database
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:populatedDatabasePath error:NULL];
    
    if ([self respondsToSelector:@selector(populateDatabase:)]) {
        FMDatabase *db = [FMDatabase databaseWithPath:populatedDatabasePath];
        
        [db open];
        [self populateDatabase:db];
        [db close];
    }
}

- (void)setUp
{
    [super setUp];
    
    // Delete the old database
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:testDatabasePath error:NULL];
    
    if ([[self class] respondsToSelector:@selector(populateDatabase:)]) {
        [fileManager copyItemAtPath:populatedDatabasePath toPath:testDatabasePath error:NULL];
    }
    
    self.db = [FMDatabase databaseWithPath:testDatabasePath];
    
    XCTAssertTrue([self.db open], @"Wasn't able to open database");
    [self.db setShouldCacheStatements:YES];
}

- (void)tearDown
{
    [super tearDown];
    
    [self.db close];
}

- (NSString *)databasePath
{
    return testDatabasePath;
}

@end
