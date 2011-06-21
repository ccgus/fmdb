//
//  Created by Chris Dolan on 6/20/11.
// For https://github.com/ccgus/fmdb/pull/20
//
//     auto-finalize statements on BUSY
//     if [FMDatabase close] results in SQLITE_BUSY, then check if there any un-finalized statements.
//     If so, finalize them. This is only needed if we're not caching statements."
//

#import "BusyDatabaseGCTest.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"


@implementation BusyDatabaseGCTest

- (void)testLeakedStatement
{
    NSString *dbPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"BusyDatabaseGCTest.db"];
    FMDatabase *db = [FMDatabase databaseWithPath:dbPath];
    [db setLogsErrors:YES];
    STAssertTrue([db open], @"open db", nil);
    [db executeUpdate:@"create table Foo (id INTEGER PRIMARY KEY, data TEXT)"]; // does not leak because it finalizes
    FMResultSet *rs = [db executeQuery:@"select * from Foo"];
    STAssertNotNil(rs, @"not null resultset", nil);
    [rs close]; // leaked FMStatement
    STAssertFalse([db hasOpenStatements], @"should have no statements open", nil);
    [db close];
    [[NSFileManager defaultManager] removeItemAtPath:dbPath error:nil];
}

@end
