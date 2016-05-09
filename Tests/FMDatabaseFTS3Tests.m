//
//  FMDatabaseFTS3Tests.m
//  fmdb
//
//  Created by Seaview Software on 8/26/14.
//
//

#import "FMDBTempDBTests.h"
#import "FMDatabase+FTS3.h"
#import "FMTokenizers.h"

@interface FMDatabaseFTS3Tests : FMDBTempDBTests

@end

/**
 This tokenizer extends the simple tokenizer to remove 's' from the end of each token if present.
 Used for testing of the tokenization system.
 */
@interface FMDepluralizerTokenizer : NSObject <FMTokenizerDelegate>
+ (instancetype)tokenizerWithBaseTokenizer:(id<FMTokenizerDelegate>)tokenizer;
@property (nonatomic, strong) id<FMTokenizerDelegate> m_baseTokenizer;
@end

static id<FMTokenizerDelegate> g_simpleTok = nil;
static id<FMTokenizerDelegate> g_depluralizeTok = nil;

@implementation FMDatabaseFTS3Tests

+ (void)populateDatabase:(FMDatabase *)db
{
    [db executeUpdate:@"CREATE VIRTUAL TABLE mail USING fts3(subject, body)"];
    
    [db executeUpdate:@"INSERT INTO mail VALUES('hello world', 'This message is a hello world message.')"];
    [db executeUpdate:@"INSERT INTO mail VALUES('urgent: serious', 'This mail is seen as a more serious mail')"];

    // Create a tokenizer instance that will not be de-allocated when the method finishes.
    g_simpleTok = [[FMSimpleTokenizer alloc] initWithLocale:NULL];
    [FMDatabase registerTokenizer:g_simpleTok withKey:@"testTok"];
    
    g_depluralizeTok = [FMDepluralizerTokenizer tokenizerWithBaseTokenizer:g_simpleTok];
    [FMDatabase registerTokenizer:g_depluralizeTok withKey:@"depluralize"];
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
    [self.db installTokenizerModule];
    
    BOOL ok = [self.db executeUpdate:@"CREATE VIRTUAL TABLE simple USING fts3(tokenize=fmdb testTok)"];
    XCTAssertTrue(ok, @"Failed to create virtual table: %@", [self.db lastErrorMessage]);

    // The FMSimpleTokenizer handles non-ASCII characters well, since it's based on CFStringTokenizer.
    NSString *text = @"I like the band Queensrÿche. They are really great musicians.";
    
    ok = [self.db executeUpdate:@"INSERT INTO simple VALUES(?)", text];
    XCTAssertTrue(ok, @"Failed to insert data: %@", [self.db lastErrorMessage]);
    
    FMResultSet *results = [self.db executeQuery:@"SELECT * FROM simple WHERE simple MATCH ?", @"Queensrÿche"];
    XCTAssertTrue([results next], @"Failed to find result");
    
    ok = [self.db executeUpdate:@"CREATE VIRTUAL TABLE depluralize_t USING fts3(tokenize=fmdb depluralize)"];
    XCTAssertTrue(ok, @"Failed to create virtual table with depluralize tokenizer: %@", [self.db lastErrorMessage]);

    ok = [self.db executeUpdate:@"INSERT INTO depluralize_t VALUES(?)", text];
    XCTAssertTrue(ok, @"Failed to insert data: %@", [self.db lastErrorMessage]);

    //If depluralization is working, searching for 'bands' should still provide a match as 'band' is in the text
    results = [self.db executeQuery:@"SELECT * FROM depluralize_t WHERE depluralize_t MATCH ?", @"bands"];
    XCTAssertTrue([results next], @"Failed to find result");
    
    //Demonstrate that depluralization mattered; we should NOT find any results when searching the simple table as it does not use that tokenizer
    results = [self.db executeQuery:@"SELECT * FROM simple WHERE simple MATCH ?", @"bands"];
    XCTAssertFalse([results next], @"Found a result where none should be found");
}

@end



#pragma mark -

@implementation FMDepluralizerTokenizer

+ (instancetype)tokenizerWithBaseTokenizer:(id<FMTokenizerDelegate>)tokenizer
{
    return [[self alloc] initWithBaseTokenizer:tokenizer];
}

- (instancetype)initWithBaseTokenizer:(id<FMTokenizerDelegate>)tokenizer
{
    NSParameterAssert(tokenizer);
    
    if ((self = [super init])) {
        self.m_baseTokenizer = tokenizer;
    }
    return self;
}

- (void)openTokenizerCursor:(FMTokenizerCursor *)cursor
{
    [self.m_baseTokenizer openTokenizerCursor:cursor];
}

- (BOOL)nextTokenForCursor:(FMTokenizerCursor *)cursor
{
    BOOL done = [self.m_baseTokenizer nextTokenForCursor:cursor];

    if (!done) {
        NSMutableString *tokenString = (__bridge NSMutableString *)(cursor->tokenString);
        if ([tokenString hasSuffix:@"s"])
            [tokenString deleteCharactersInRange:NSMakeRange(tokenString.length-1, 1)];
    }

    return done;
}

- (void)closeTokenizerCursor:(FMTokenizerCursor *)cursor
{
    [self.m_baseTokenizer closeTokenizerCursor:cursor];
}


@end
