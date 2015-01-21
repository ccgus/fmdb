//
//  FMDatabaseFTS3WithKeyTests.m
//  fmdb
//
//  Created by Stephan Heilner on 1/21/15.
//
//

#import "FMDBTempDBTests.h"
#import "FMDatabase+FTS3.h"
#import "FMTokenizers.h"

@interface FMDatabaseFTS3WithModuleNameTests : FMDBTempDBTests

@end

static id<FMTokenizerDelegate> g_testTok = nil;

@implementation FMDatabaseFTS3WithModuleNameTests

+ (void)populateDatabase:(FMDatabase *)db
{
    [db executeUpdate:@"CREATE VIRTUAL TABLE mail USING fts3(subject, body)"];
    
    [db executeUpdate:@"INSERT INTO mail VALUES('hello world', 'This message is a hello world message.')"];
    [db executeUpdate:@"INSERT INTO mail VALUES('urgent: serious', 'This mail is seen as a more serious mail')"];
    
    // Create a tokenizer instance that will not be de-allocated when the method finishes.
    g_testTok = [[FMSimpleTokenizer alloc] initWithLocale:NULL];
    [FMDatabase registerTokenizer:g_testTok];
}

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

- (void)testOffsets
{
    FMResultSet *results = [self.db executeQuery:@"SELECT offsets(mail) FROM mail WHERE mail MATCH 'world'"];
    
    if ([results next]) {
        FMTextOffsets *offsets = [results offsetsForColumnIndex:0];
        
        [offsets enumerateWithBlock:^(NSInteger columnNumber, NSInteger termNumber, NSRange matchRange) {
            if (columnNumber == 0) {
                XCTAssertEqual(termNumber, 0L);
                XCTAssertEqual(matchRange.location, 6UL);
                XCTAssertEqual(matchRange.length, 5UL);
            } else if (columnNumber == 1) {
                XCTAssertEqual(termNumber, 0L);
                XCTAssertEqual(matchRange.location, 24UL);
                XCTAssertEqual(matchRange.length, 5UL);
            }
        }];
    }
}

- (void)testTokenizer
{
    [self.db installTokenizerModuleWithName:@"TestModuleName"];
    
    BOOL ok = [self.db executeUpdate:@"CREATE VIRTUAL TABLE simple_fts USING fts3(tokenize=TestModuleName)"];
    XCTAssertTrue(ok, @"Failed to create virtual table: %@", [self.db lastErrorMessage]);
    
    // The FMSimpleTokenizer handles non-ASCII characters well, since it's based on CFStringTokenizer.
    NSString *text = @"I like the band Queensrÿche. They are really great.";
    
    ok = [self.db executeUpdate:@"INSERT INTO simple_fts VALUES(?)", text];
    XCTAssertTrue(ok, @"Failed to insert data: %@", [self.db lastErrorMessage]);
    
    FMResultSet *results = [self.db executeQuery:@"SELECT * FROM simple_fts WHERE simple_fts MATCH ?", @"Queensrÿche"];
    XCTAssertTrue([results next], @"Failed to find result");
}

@end
