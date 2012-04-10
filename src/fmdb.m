#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabasePool.h"
#import "FMDatabaseQueue.h"

#define FMDBQuickCheck(SomeBool) { if (!(SomeBool)) { NSLog(@"Failure on line %d", __LINE__); abort(); } }

void testPool(NSString *dbPath);

int main (int argc, const char * argv[]) {
    
@autoreleasepool {
        
    
    NSString *dbPath = @"/tmp/tmp.db";
    
    // delete the old db.
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:dbPath error:nil];
    
    FMDatabase *db = [FMDatabase databaseWithPath:dbPath];
    
    NSLog(@"Is SQLite compiled with it's thread safe options turned on? %@!", [FMDatabase isSQLiteThreadSafe] ? @"Yes" : @"No");
    
    {
        // -------------------------------------------------------------------------------
        // Un-opened database check.
        FMDBQuickCheck([db executeQuery:@"select * from table"] == nil);
        NSLog(@"%d: %@", [db lastErrorCode], [db lastErrorMessage]);
    }
    
    
    if (![db open]) {
        NSLog(@"Could not open db.");
        
        return 0;
    }
    
    // kind of experimentalish.
    [db setShouldCacheStatements:YES];
    
    // create a bad statement, just to test the error code.
    [db executeUpdate:@"blah blah blah"];
    
    FMDBQuickCheck([db hadError]);
    
    if ([db hadError]) {
        NSLog(@"Err %d: %@", [db lastErrorCode], [db lastErrorMessage]);
    }
    
    NSError *err = 0x00;
    FMDBQuickCheck(![db update:@"blah blah blah" withErrorAndBindings:&err]);
    FMDBQuickCheck(err != nil);
    FMDBQuickCheck([err code] == SQLITE_ERROR);
    NSLog(@"err: '%@'", err);
    
    // but of course, I don't bother checking the error codes below.
    // Bad programmer, no cookie.
    
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
    
    
    
    
    
    FMResultSet *rs = [db executeQuery:@"select rowid,* from test where a = ?", @"hi'"];
    while ([rs next]) {
        // just print out what we've got in a number of formats.
        NSLog(@"%d %@ %@ %@ %@ %f %f",
              [rs intForColumn:@"c"],
              [rs stringForColumn:@"b"],
              [rs stringForColumn:@"a"],
              [rs stringForColumn:@"rowid"],
              [rs dateForColumn:@"d"],
              [rs doubleForColumn:@"d"],
              [rs doubleForColumn:@"e"]);
        
        
        if (!([[rs columnNameForIndex:0] isEqualToString:@"rowid"] &&
              [[rs columnNameForIndex:1] isEqualToString:@"a"])
              ) {
            NSLog(@"WHOA THERE BUDDY, columnNameForIndex ISN'T WORKING!");
            return 7;
        }
    }
    // close the result set.
    // it'll also close when it's dealloc'd, but we're closing the database before
    // the autorelease pool closes, so sqlite will complain about it.
    [rs close];  
    
    FMDBQuickCheck(![db hasOpenResultSets]);
    
    [db executeUpdate:@"create table ull (a integer)"];
    
    [db executeUpdate:@"insert into ull (a) values (?)" , [NSNumber numberWithUnsignedLongLong:ULLONG_MAX]];
    
    rs = [db executeQuery:@"select  a from ull"];
    while ([rs next]) {
        unsigned long long a = [rs unsignedLongLongIntForColumnIndex:0];
        unsigned long long b = [rs unsignedLongLongIntForColumn:@"a"];
        
        FMDBQuickCheck(a == ULLONG_MAX);
        FMDBQuickCheck(b == ULLONG_MAX);
    }
    
    
    // check case sensitive result dictionary.
    [db executeUpdate:@"create table cs (aRowName integer, bRowName text)"];
    FMDBQuickCheck(![db hadError]);
    [db executeUpdate:@"insert into cs (aRowName, bRowName) values (?, ?)" , [NSNumber numberWithBool:1], @"hello"];
    FMDBQuickCheck(![db hadError]);
    
    rs = [db executeQuery:@"select * from cs"];
    while ([rs next]) {
        NSDictionary *d = [rs resultDictionary];
        
        FMDBQuickCheck([d objectForKey:@"aRowName"]);
        FMDBQuickCheck(![d objectForKey:@"arowname"]);
        FMDBQuickCheck([d objectForKey:@"bRowName"]);
        FMDBQuickCheck(![d objectForKey:@"browname"]);
    }
    
    
    // check funky table names + getTableSchema
    [db executeUpdate:@"create table '234 fds' (foo text)"];
    FMDBQuickCheck(![db hadError]);
    rs = [db getTableSchema:@"234 fds"];
    FMDBQuickCheck([rs next]);
    [rs close];
    
    
    
    // ----------------------------------------------------------------------------------------
    // blob support.
    [db executeUpdate:@"create table blobTable (a text, b blob)"];
    
    // let's read in an image from safari's app bundle.
    NSData *safariCompass = [NSData dataWithContentsOfFile:@"/Applications/Safari.app/Contents/Resources/compass.icns"];
    if (safariCompass) {
        [db executeUpdate:@"insert into blobTable (a, b) values (?,?)", @"safari's compass", safariCompass];
        
        rs = [db executeQuery:@"select b from blobTable where a = ?", @"safari's compass"];
        if ([rs next]) {
            safariCompass = [rs dataForColumn:@"b"];
            [safariCompass writeToFile:@"/tmp/compass.icns" atomically:NO];
            
            // let's look at our fancy image that we just wrote out..
            system("/usr/bin/open /tmp/compass.icns");
            
            // ye shall read the header for this function, or suffer the consequences.
            safariCompass = [rs dataNoCopyForColumn:@"b"];
            [safariCompass writeToFile:@"/tmp/compass_data_no_copy.icns" atomically:NO];
            system("/usr/bin/open /tmp/compass_data_no_copy.icns");
        }
        else {
            NSLog(@"Could not select image.");
        }
        
        [rs close];
        
    }
    else {
        NSLog(@"Can't find compass image..");
    }
    
    
    // test out the convenience methods in +Additions
    [db executeUpdate:@"create table t1 (a integer)"];
    [db executeUpdate:@"insert into t1 values (?)", [NSNumber numberWithInt:5]];
    
    NSLog(@"Count of changes (should be 1): %d", [db changes]);
    FMDBQuickCheck([db changes] == 1);
    
    int a = [db intForQuery:@"select a from t1 where a = ?", [NSNumber numberWithInt:5]];
    if (a != 5) {
        NSLog(@"intForQuery didn't work (a != 5)");
    }
    
    // test the busy rety timeout schtuff.
    
    [db setBusyRetryTimeout:500];
    
    FMDatabase *newDb = [FMDatabase databaseWithPath:dbPath];
    [newDb open];
    
    rs = [newDb executeQuery:@"select rowid,* from test where a = ?", @"hi'"];
    [rs next]; // just grab one... which will keep the db locked.
    
    NSLog(@"Testing the busy timeout");
    
    BOOL success = [db executeUpdate:@"insert into t1 values (5)"];
    
    if (success) {
        NSLog(@"Whoa- the database didn't stay locked!");
        return 7;
    }
    else {
        NSLog(@"Hurray, our timeout worked");
    }
    
    [rs close];
    [newDb close];
    
    success = [db executeUpdate:@"insert into t1 values (5)"];
    if (!success) {
        NSLog(@"Whoa- the database shouldn't be locked!");
        return 8;
    }
    else {
        NSLog(@"Hurray, we can insert again!");
    }
    
    
    
    // test some nullness.
    [db executeUpdate:@"create table t2 (a integer, b integer)"];
    
    if (![db executeUpdate:@"insert into t2 values (?, ?)", nil, [NSNumber numberWithInt:5]]) {
        NSLog(@"UH OH, can't insert a nil value for some reason...");
    }
    
    
    
    
    rs = [db executeQuery:@"select * from t2"];
    while ([rs next]) {
        NSString *a = [rs stringForColumnIndex:0];
        NSString *b = [rs stringForColumnIndex:1];
        
        if (a != nil) {
            NSLog(@"%s:%d", __FUNCTION__, __LINE__);
            NSLog(@"OH OH, PROBLEMO!");
            return 10;
        }
        else {
            NSLog(@"YAY, NULL VALUES");
        }
        
        if (![b isEqualToString:@"5"]) {
            NSLog(@"%s:%d", __FUNCTION__, __LINE__);
            NSLog(@"OH OH, PROBLEMO!");
            return 10;
        }
    }
    
    
    
    
    
    
    
    
    
    
    // test some inner loop funkness.
    [db executeUpdate:@"create table t3 (a somevalue)"];
    
    
    // do it again, just because
    [db beginTransaction];
    i = 0;
    while (i++ < 20) {
        [db executeUpdate:@"insert into t3 (a) values (?)" , [NSNumber numberWithInt:i]];
    }
    [db commit];
    
    
    
    
    rs = [db executeQuery:@"select * from t3"];
    while ([rs next]) {
        int foo = [rs intForColumnIndex:0];
        
        int newVal = foo + 100;
        
        [db executeUpdate:@"update t3 set a = ? where a = ?" , [NSNumber numberWithInt:newVal], [NSNumber numberWithInt:foo]];
        
        
        FMResultSet *rs2 = [db executeQuery:@"select a from t3 where a = ?", [NSNumber numberWithInt:newVal]];
        [rs2 next];
        
        if ([rs2 intForColumnIndex:0] != newVal) {
            NSLog(@"Oh crap, our update didn't work out!");
            return 9;
        }
        
        [rs2 close];
    }
    
    
    // NSNull tests
    [db executeUpdate:@"create table nulltest (a text, b text)"];
    
    [db executeUpdate:@"insert into nulltest (a, b) values (?, ?)" , [NSNull null], @"a"];
    [db executeUpdate:@"insert into nulltest (a, b) values (?, ?)" , nil, @"b"];
    
    rs = [db executeQuery:@"select * from nulltest"];
    
    while ([rs next]) {
        
        NSString *a = [rs stringForColumnIndex:0];
        NSString *b = [rs stringForColumnIndex:1];
        
        if (!b) {
            NSLog(@"Oh crap, the nil / null inserts didn't work!");
            return 10;
        }
        
        if (a) {
            NSLog(@"Oh crap, the nil / null inserts didn't work (son of error message)!");
            return 11;
        }
        else {
            NSLog(@"HURRAH FOR NSNULL (and nil)!");
        }
    }
    
    
    
    
    
    
    // null dates
    
    NSDate *date = [NSDate date];
    [db executeUpdate:@"create table datetest (a double, b double, c double)"];
    [db executeUpdate:@"insert into datetest (a, b, c) values (?, ?, 0)" , [NSNull null], date];
    
    rs = [db executeQuery:@"select * from datetest"];
    
    while ([rs next]) {
        
        NSDate *a = [rs dateForColumnIndex:0];
        NSDate *b = [rs dateForColumnIndex:1];
        NSDate *c = [rs dateForColumnIndex:2];
        
        if (a) {
            NSLog(@"Oh crap, the null date insert didn't work!");
            return 12;
        }
        
        if (!c) {
            NSLog(@"Oh crap, the 0 date insert didn't work!");
            return 12;
        }
        
        NSTimeInterval dti = fabs([b timeIntervalSinceDate:date]);
        
        if (floor(dti) > 0.0) {
            NSLog(@"Date matches didn't really happen... time difference of %f", dti);
            return 13;
        }
        
        
        dti = fabs([c timeIntervalSinceDate:[NSDate dateWithTimeIntervalSince1970:0]]);
        
        if (floor(dti) > 0.0) {
            NSLog(@"Date matches didn't really happen... time difference of %f", dti);
            return 13;
        }
    }
    
    NSDate *foo = [db dateForQuery:@"select b from datetest where c = 0"];
    assert(foo);
    NSTimeInterval dti = fabs([foo timeIntervalSinceDate:date]);
    if (floor(dti) > 0.0) {
        NSLog(@"Date matches didn't really happen... time difference of %f", dti);
        return 14;
    }
    
    [db executeUpdate:@"create table nulltest2 (s text, d data, i integer, f double, b integer)"];
    
    [db executeUpdate:@"insert into nulltest2 (s, d, i, f, b) values (?, ?, ?, ?, ?)" , @"Hi", safariCompass, [NSNumber numberWithInt:12], [NSNumber numberWithFloat:4.4f], [NSNumber numberWithBool:YES]];
    [db executeUpdate:@"insert into nulltest2 (s, d, i, f, b) values (?, ?, ?, ?, ?)" , nil, nil, nil, nil, [NSNull null]];
    
    rs = [db executeQuery:@"select * from nulltest2"];
    
    while ([rs next]) {
        
        int i = [rs intForColumnIndex:2];
        
        if (i == 12) {
            // it's the first row we inserted.
            FMDBQuickCheck(![rs columnIndexIsNull:0]);
            FMDBQuickCheck(![rs columnIndexIsNull:1]);
            FMDBQuickCheck(![rs columnIndexIsNull:2]);
            FMDBQuickCheck(![rs columnIndexIsNull:3]);
            FMDBQuickCheck(![rs columnIndexIsNull:4]);
            FMDBQuickCheck( [rs columnIndexIsNull:5]);
            
            FMDBQuickCheck([[rs dataForColumn:@"d"] length] == [safariCompass length]);
            FMDBQuickCheck(![rs dataForColumn:@"notthere"]);
            FMDBQuickCheck(![rs stringForColumnIndex:-2]);
            FMDBQuickCheck([rs boolForColumnIndex:4]);
            FMDBQuickCheck([rs boolForColumn:@"b"]);
            
            FMDBQuickCheck(fabs(4.4 - [rs doubleForColumn:@"f"]) < 0.0000001);
            
            FMDBQuickCheck(12 == [rs intForColumn:@"i"]);
            FMDBQuickCheck(12 == [rs intForColumnIndex:2]);
            
            FMDBQuickCheck(0 == [rs intForColumnIndex:12]); // there is no 12
            FMDBQuickCheck(0 == [rs intForColumn:@"notthere"]);
            
            FMDBQuickCheck(12 == [rs longForColumn:@"i"]);
            FMDBQuickCheck(12 == [rs longLongIntForColumn:@"i"]);
        }
        else {
            // let's test various null things.
            
            FMDBQuickCheck([rs columnIndexIsNull:0]);
            FMDBQuickCheck([rs columnIndexIsNull:1]);
            FMDBQuickCheck([rs columnIndexIsNull:2]);
            FMDBQuickCheck([rs columnIndexIsNull:3]);
            FMDBQuickCheck([rs columnIndexIsNull:4]);
            FMDBQuickCheck([rs columnIndexIsNull:5]);
            
            
            FMDBQuickCheck(![rs dataForColumn:@"d"]);
            
        }
    }
    
    
    
    {
        [db executeUpdate:@"create table testOneHundredTwelvePointTwo (a text, b integer)"];
        [db executeUpdate:@"insert into testOneHundredTwelvePointTwo values (?, ?)" withArgumentsInArray:[NSArray arrayWithObjects:@"one", [NSNumber numberWithInteger:2], nil]];
        [db executeUpdate:@"insert into testOneHundredTwelvePointTwo values (?, ?)" withArgumentsInArray:[NSArray arrayWithObjects:@"one", [NSNumber numberWithInteger:3], nil]];
        
        
        rs = [db executeQuery:@"select * from testOneHundredTwelvePointTwo where b > ?" withArgumentsInArray:[NSArray arrayWithObject:[NSNumber numberWithInteger:1]]];
        
        FMDBQuickCheck([rs next]);
        
        FMDBQuickCheck([rs hasAnotherRow]);
        FMDBQuickCheck(![db hadError]);
        
        FMDBQuickCheck([[rs stringForColumnIndex:0] isEqualToString:@"one"]);
        FMDBQuickCheck([rs intForColumnIndex:1] == 2);
        
        FMDBQuickCheck([rs next]);
        
        FMDBQuickCheck([rs intForColumnIndex:1] == 3);
        
        FMDBQuickCheck(![rs next]);
        FMDBQuickCheck(![rs hasAnotherRow]);
        
    }
    
    {
        
        FMDBQuickCheck([db executeUpdate:@"create table t4 (a text, b text)"]);
        FMDBQuickCheck(([db executeUpdate:@"insert into t4 (a, b) values (?, ?)", @"one", @"two"]));
        
        rs = [db executeQuery:@"select t4.a as 't4.a', t4.b from t4;"];
        
        FMDBQuickCheck((rs != nil));
        
        [rs next];
        
        FMDBQuickCheck([[rs stringForColumn:@"t4.a"] isEqualToString:@"one"]);
        FMDBQuickCheck([[rs stringForColumn:@"b"] isEqualToString:@"two"]);
        
        FMDBQuickCheck(strcmp((const char*)[rs UTF8StringForColumnName:@"b"], "two") == 0);
        
        [rs close];
        
        // let's try these again, with the withArgumentsInArray: variation
        FMDBQuickCheck([db executeUpdate:@"drop table t4;" withArgumentsInArray:[NSArray array]]);
        FMDBQuickCheck([db executeUpdate:@"create table t4 (a text, b text)" withArgumentsInArray:[NSArray array]]);
        FMDBQuickCheck(([db executeUpdate:@"insert into t4 (a, b) values (?, ?)" withArgumentsInArray:[NSArray arrayWithObjects:@"one", @"two", nil]]));
        
        rs = [db executeQuery:@"select t4.a as 't4.a', t4.b from t4;" withArgumentsInArray:[NSArray array]];
        
        FMDBQuickCheck((rs != nil));
        
        [rs next];
        
        FMDBQuickCheck([[rs stringForColumn:@"t4.a"] isEqualToString:@"one"]);
        FMDBQuickCheck([[rs stringForColumn:@"b"] isEqualToString:@"two"]);
        
        FMDBQuickCheck(strcmp((const char*)[rs UTF8StringForColumnName:@"b"], "two") == 0);
        
        [rs close];
    }
    
    
    
    
    {
        FMDBQuickCheck([db tableExists:@"t4"]);
        FMDBQuickCheck(![db tableExists:@"thisdoesntexist"]);
        
        rs = [db getSchema];
        while ([rs next]) {
            FMDBQuickCheck([[rs stringForColumn:@"type"] isEqualToString:@"table"]);
        }
    }
    
    
    {
        FMDBQuickCheck([db executeUpdate:@"create table t5 (a text, b int, c blob, d text, e text)"]);
        FMDBQuickCheck(([db executeUpdateWithFormat:@"insert into t5 values (%s, %d, %@, %c, %lld)", "text", 42, @"BLOB", 'd', 12345678901234]));
        
        rs = [db executeQueryWithFormat:@"select * from t5 where a = %s", "text"];
        FMDBQuickCheck((rs != nil));
        
        [rs next];
        
        FMDBQuickCheck([[rs stringForColumn:@"a"] isEqualToString:@"text"]);
        FMDBQuickCheck(([rs intForColumn:@"b"] == 42));
        FMDBQuickCheck([[rs stringForColumn:@"c"] isEqualToString:@"BLOB"]);
        FMDBQuickCheck([[rs stringForColumn:@"d"] isEqualToString:@"d"]);
        FMDBQuickCheck(([rs longLongIntForColumn:@"e"] == 12345678901234));
        
        [rs close];
    }
    
    
    
    {
        FMDBQuickCheck([db executeUpdate:@"create table t55 (a text, b int, c float)"]);
        short testShort = -4;
        float testFloat = 5.5;
        FMDBQuickCheck(([db executeUpdateWithFormat:@"insert into t55 values (%c, %hi, %g)", 'a', testShort, testFloat]));
        
        unsigned short testUShort = 6;
        FMDBQuickCheck(([db executeUpdateWithFormat:@"insert into t55 values (%c, %hu, %g)", 'a', testUShort, testFloat]));
        
        
        rs = [db executeQueryWithFormat:@"select * from t55 where a = %s order by 2", "a"];
        FMDBQuickCheck((rs != nil));
        
        [rs next];
        
        FMDBQuickCheck([[rs stringForColumn:@"a"] isEqualToString:@"a"]);
        FMDBQuickCheck(([rs intForColumn:@"b"] == -4));
        FMDBQuickCheck([[rs stringForColumn:@"c"] isEqualToString:@"5.5"]);
        
        
        [rs next];
        
        FMDBQuickCheck([[rs stringForColumn:@"a"] isEqualToString:@"a"]);
        FMDBQuickCheck(([rs intForColumn:@"b"] == 6));
        FMDBQuickCheck([[rs stringForColumn:@"c"] isEqualToString:@"5.5"]);
        
        [rs close];
        
    }
    
    
    
    
    {
        NSError *err;
        FMDBQuickCheck(([db update:@"insert into t5 values (?, ?, ?, ?, ?)" withErrorAndBindings:&err, @"text", [NSNumber numberWithInt:42], @"BLOB", @"d", [NSNumber numberWithInt:0]]));
        
    }
    
    
    // test attach for the heck of it.
    {
        
        //FMDatabase *dbA = [FMDatabase databaseWithPath:dbPath];
        [fileManager removeItemAtPath:@"/tmp/attachme.db" error:nil];
        FMDatabase *dbB = [FMDatabase databaseWithPath:@"/tmp/attachme.db"];
        FMDBQuickCheck([dbB open]);
        FMDBQuickCheck([dbB executeUpdate:@"create table attached (a text)"]);
        FMDBQuickCheck(([dbB executeUpdate:@"insert into attached values (?)", @"test"]));
        FMDBQuickCheck([dbB close]);
        
        [db executeUpdate:@"attach database '/tmp/attachme.db' as attack"];
        
        rs = [db executeQuery:@"select * from attack.attached"];
        FMDBQuickCheck([rs next]);
        [rs close];
        
    }
    
    
    
    {
        // -------------------------------------------------------------------------------
        // Named parameters.
        FMDBQuickCheck([db executeUpdate:@"create table namedparamtest (a text, b text, c integer, d double)"]);
        NSMutableDictionary *dictionaryArgs = [NSMutableDictionary dictionary];
        [dictionaryArgs setObject:@"Text1" forKey:@"a"];
        [dictionaryArgs setObject:@"Text2" forKey:@"b"];
        [dictionaryArgs setObject:[NSNumber numberWithInt:1] forKey:@"c"];
        [dictionaryArgs setObject:[NSNumber numberWithDouble:2.0] forKey:@"d"];
        FMDBQuickCheck([db executeUpdate:@"insert into namedparamtest values (:a, :b, :c, :d)" withParameterDictionary:dictionaryArgs]);
        
        rs = [db executeQuery:@"select * from namedparamtest"];
        
        FMDBQuickCheck((rs != nil));
        
        [rs next];
        
        FMDBQuickCheck([[rs stringForColumn:@"a"] isEqualToString:@"Text1"]);
        FMDBQuickCheck([[rs stringForColumn:@"b"] isEqualToString:@"Text2"]);
        FMDBQuickCheck([rs intForColumn:@"c"] == 1);
        FMDBQuickCheck([rs doubleForColumn:@"d"] == 2.0);
        
        [rs close];
        
        
        dictionaryArgs = [NSMutableDictionary dictionary];
        
        [dictionaryArgs setObject:@"Text2" forKey:@"blah"];
        
        rs = [db executeQuery:@"select * from namedparamtest where b = :blah" withParameterDictionary:dictionaryArgs];
        
        FMDBQuickCheck((rs != nil));
        FMDBQuickCheck([rs next]);
        FMDBQuickCheck([[rs stringForColumn:@"b"] isEqualToString:@"Text2"]);
        
        [rs close];
        
        
        
        
    }
    
    // just for fun.
    rs = [db executeQuery:@"PRAGMA database_list"];
    while ([rs next]) {
        NSString *file = [rs stringForColumn:@"file"];
        NSLog(@"database_list: %@", file);
    }
    
    
    // print out some stats if we are using cached statements.
    if ([db shouldCacheStatements]) {
        
        NSEnumerator *e = [[db cachedStatements] objectEnumerator];;
        FMStatement *statement;
        
        while ((statement = [e nextObject])) {
            NSLog(@"%@", statement);
        }
    }
    
    
    [db close];
    
    
    testPool(dbPath);
    
    
    
    FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
    
    FMDBQuickCheck(queue);
    
    {
        [queue inDatabase:^(FMDatabase *db) {
            
            
            
            [db executeUpdate:@"create table qfoo (foo text)"];
            [db executeUpdate:@"insert into qfoo values ('hi')"];
            [db executeUpdate:@"insert into qfoo values ('hello')"];
            [db executeUpdate:@"insert into qfoo values ('not')"];
            
            
            
            int count = 0;
            FMResultSet *rsl = [db executeQuery:@"select * from qfoo where foo like 'h%'"];
            while ([rsl next]) {
                count++;
            }
            
            FMDBQuickCheck(count == 2);
            
            count = 0;
            rsl = [db executeQuery:@"select * from qfoo where foo like ?", @"h%"];
            while ([rsl next]) {
                count++;
            }
            
            FMDBQuickCheck(count == 2);
        }];
        
    }
    
    
    {
        // You should see pairs of numbers show up in stdout for this stuff:
        int ops = 16;
        
        dispatch_queue_t dqueue = dispatch_get_global_queue(0, DISPATCH_QUEUE_PRIORITY_HIGH);
        
        dispatch_apply(ops, dqueue, ^(size_t nby) {
            
            // just mix things up a bit for demonstration purposes.
            if (nby % 2 == 1) {
                [NSThread sleepForTimeInterval:.1];
                
                [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
                    NSLog(@"Starting query  %ld", nby);
                    
                    FMResultSet *rsl = [db executeQuery:@"select * from qfoo where foo like 'h%'"];
                    while ([rsl next]) {
                        ;// whatever.
                    }
                    
                    NSLog(@"Ending query    %ld", nby);
                }];
                
            }
            
            if (nby % 3 == 1) {
                [NSThread sleepForTimeInterval:.1];
            }
            
            [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
                NSLog(@"Starting update %ld", nby);
                [db executeUpdate:@"insert into qfoo values ('1')"];
                [db executeUpdate:@"insert into qfoo values ('2')"];
                [db executeUpdate:@"insert into qfoo values ('3')"];
                NSLog(@"Ending update   %ld", nby);
            }];
        });
        
        [queue close];
        
        [queue inDatabase:^(FMDatabase *db) {
            FMDBQuickCheck([db executeUpdate:@"insert into qfoo values ('1')"]);
        }];
    }
    
    
    
    {
        [queue inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"create table transtest (a integer)"];
            FMDBQuickCheck([db executeUpdate:@"insert into transtest values (1)"]);
            FMDBQuickCheck([db executeUpdate:@"insert into transtest values (2)"]);
            
            int rowCount = 0;
            FMResultSet *rs = [db executeQuery:@"select * from transtest"];
            while ([rs next]) {
                rowCount++;
            }
            
            FMDBQuickCheck(rowCount == 2);
        }];
        
        
        
        [queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            FMDBQuickCheck([db executeUpdate:@"insert into transtest values (3)"]);
            
            if (YES) {
                // uh oh!, something went wrong (not really, this is just a test
                *rollback = YES;
                return;
            }
            
            FMDBQuickCheck([db executeUpdate:@"insert into transtest values (4)"]);
        }];
        
        [queue inDatabase:^(FMDatabase *db) {
        
            int rowCount = 0;
            FMResultSet *rs = [db executeQuery:@"select * from transtest"];
            while ([rs next]) {
                rowCount++;
            }
            
            FMDBQuickCheck(![db hasOpenResultSets]);
            
            NSLog(@"after rollback, rowCount is %d (should be 2)", rowCount);
            
            FMDBQuickCheck(rowCount == 2);
        }];
    }
    
    // hey, let's make a custom function!
    
    [queue inDatabase:^(FMDatabase *db) {
        
        [db executeUpdate:@"create table ftest (foo text)"];
        [db executeUpdate:@"insert into ftest values ('hello')"];
        [db executeUpdate:@"insert into ftest values ('hi')"];
        [db executeUpdate:@"insert into ftest values ('not h!')"];
        [db executeUpdate:@"insert into ftest values ('definitely not h!')"];
        
        [db makeFunctionNamed:@"StringStartsWithH" maximumArguments:1 withBlock:^(sqlite3_context *context, int argc, sqlite3_value **argv) {
            if (sqlite3_value_type(argv[0]) == SQLITE_TEXT) {
                
                @autoreleasepool {
                    
                    const char *c = (const char *)sqlite3_value_text(argv[0]);
                    
                    NSString *s = [NSString stringWithUTF8String:c];
                    
                    sqlite3_result_int(context, [s hasPrefix:@"h"]);
                }
            }
            else {
                NSLog(@"Unknown format for StringStartsWithH (%d) %s:%d", sqlite3_value_type(argv[0]), __FUNCTION__, __LINE__);
                sqlite3_result_null(context);
            }
        }];
        
        int rowCount = 0;
        FMResultSet *rs = [db executeQuery:@"select * from ftest where StringStartsWithH(foo)"];
        while ([rs next]) {
            rowCount++;
            
            NSLog(@"Does %@ start with 'h'?", [rs stringForColumnIndex:0]);
            
        }
        FMDBQuickCheck(rowCount == 2);
        
        
        
        
        
        
    }];
    
    // safely switch between databases
    {
        [queue close];
        [fileManager removeItemAtPath:dbPath error:nil];
        queue = [FMDatabaseQueue databaseQueueWithPath:dbPath];
        FMDBQuickCheck(queue);

        [fileManager removeItemAtPath:@"/tmp/second.db" error:nil];
        
        // make sure we can switch to dbB and query it successfully
        FMDatabase *dbB = [FMDatabase databaseWithPath:@"/tmp/second.db"];
        [dbB open];
        [dbB executeUpdate:@"create table test (a text, b text, c integer, d double, e double)"];
        [dbB beginTransaction];
        int i = 0;
        while (i++ < 20) {
            [dbB executeUpdate:@"insert into test (a, b, c, d, e) values (?, ?, ?, ?, ?)" ,
             @"hi'", // look!  I put in a ', and I'm not escaping it!
             [NSString stringWithFormat:@"number %d", i],
             [NSNumber numberWithInt:i],
             [NSDate date],
             [NSNumber numberWithFloat:2.2f]];
        }
        [dbB commit];
        [dbB close];

        [queue switchToDatabaseWithPath:@"/tmp/second.db"];
        [queue inDatabase:^(FMDatabase *db) {
            int count = 0;
            FMResultSet *rsl = [db executeQuery:@"select * from test where a like 'h%'"];
            while ([rsl next]) {
                count++;
            }
            FMDBQuickCheck(count == 20);
        }];
        

        
    }
    
    NSLog(@"That was version %@ of sqlite", [FMDatabase sqliteLibVersion]);
    
    
}// this is the end of our @autorelease pool.
    
    
    return 0;
}

/*
 Test the various FMDatabasePool things.
*/

void testPool(NSString *dbPath) {
    
    FMDatabasePool *dbPool = [FMDatabasePool databasePoolWithPath:dbPath];
    
    FMDBQuickCheck([dbPool countOfOpenDatabases] == 0);
    
    __block FMDatabase *db1;
    
    [dbPool inDatabase:^(FMDatabase *db) {
        
        
        
        FMDBQuickCheck([dbPool countOfOpenDatabases] == 1);
        
        FMDBQuickCheck([db tableExists:@"t4"]);
        
        db1 = db;
        
    }];
    
    [dbPool inDatabase:^(FMDatabase *db) {
        FMDBQuickCheck(db1 == db);
        
        [dbPool inDatabase:^(FMDatabase *db2) {
            FMDBQuickCheck(db2 != db);
        }];
        
    }];
    
    
    
    FMDBQuickCheck([dbPool countOfOpenDatabases] == 2);
    
    
    [dbPool inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"create table easy (a text)"];
        [db executeUpdate:@"create table easy2 (a text)"];
        
    }];
    
    
    FMDBQuickCheck([dbPool countOfOpenDatabases] == 2);
    
    [dbPool releaseAllDatabases];
    
    FMDBQuickCheck([dbPool countOfOpenDatabases] == 0);
    
    [dbPool inDatabase:^(FMDatabase *aDb) {
        
        FMDBQuickCheck([dbPool countOfCheckedInDatabases] == 0);
        FMDBQuickCheck([dbPool countOfCheckedOutDatabases] == 1);
        
        FMDBQuickCheck([aDb tableExists:@"t4"]);
        
        FMDBQuickCheck([dbPool countOfCheckedInDatabases] == 0);
        FMDBQuickCheck([dbPool countOfCheckedOutDatabases] == 1);
        
        FMDBQuickCheck(([aDb executeUpdate:@"insert into easy (a) values (?)", @"hi"]));
        
        // just for fun.
        FMResultSet *rs2 = [aDb executeQuery:@"select * from easy"];
        FMDBQuickCheck([rs2 next]);
        while ([rs2 next]) { ; } // whatevers.
        
        FMDBQuickCheck([dbPool countOfOpenDatabases] == 1);
        FMDBQuickCheck([dbPool countOfCheckedInDatabases] == 0);
        FMDBQuickCheck([dbPool countOfCheckedOutDatabases] == 1);
    }];
    
    
    FMDBQuickCheck([dbPool countOfOpenDatabases] == 1);
    
    
    {
        
       [dbPool inDatabase:^(FMDatabase *db) {
        
            [db executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1]];
            [db executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:2]];
            [db executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:3]];
            
            FMDBQuickCheck([dbPool countOfCheckedInDatabases] == 0);
            FMDBQuickCheck([dbPool countOfCheckedOutDatabases] == 1);
       }];
    }
    
    
    FMDBQuickCheck([dbPool countOfOpenDatabases] == 1);
    
    [dbPool setMaximumNumberOfDatabasesToCreate:2];
    
    
    [dbPool inDatabase:^(FMDatabase *db) {
        [dbPool inDatabase:^(FMDatabase *db2) {
            [dbPool inDatabase:^(FMDatabase *db3) {
                FMDBQuickCheck([dbPool countOfOpenDatabases] == 2);
                FMDBQuickCheck(!db3);
            }];
            
        }];
    }];
    
    [dbPool setMaximumNumberOfDatabasesToCreate:0];
    
    [dbPool releaseAllDatabases];
    
    FMDBQuickCheck([dbPool countOfOpenDatabases] == 0);
    
    [dbPool inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:3]];
    }];
    
    
    FMDBQuickCheck([dbPool countOfOpenDatabases] == 1);
    
    
    [dbPool inTransaction:^(FMDatabase *adb, BOOL *rollback) {
        [adb executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1001]];
        [adb executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1002]];
        [adb executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1003]];
        
        FMDBQuickCheck([dbPool countOfOpenDatabases] == 1);
        FMDBQuickCheck([dbPool countOfCheckedInDatabases] == 0);
        FMDBQuickCheck([dbPool countOfCheckedOutDatabases] == 1);
    }];
    
    
    FMDBQuickCheck([dbPool countOfOpenDatabases] == 1);
    FMDBQuickCheck([dbPool countOfCheckedInDatabases] == 1);
    FMDBQuickCheck([dbPool countOfCheckedOutDatabases] == 0);
    
    
    [dbPool inDatabase:^(FMDatabase *db) {
        FMResultSet *rs2 = [db executeQuery:@"select * from easy where a = ?", [NSNumber numberWithInt:1001]];
        FMDBQuickCheck([rs2 next]);
        FMDBQuickCheck(![rs2 next]);
    }];
    
    
    
    [dbPool inDeferredTransaction:^(FMDatabase *adb, BOOL *rollback) {
        [adb executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1004]];
        [adb executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1005]];
        
        *rollback = YES;
    }];
    
    FMDBQuickCheck([dbPool countOfOpenDatabases] == 1);
    FMDBQuickCheck([dbPool countOfCheckedInDatabases] == 1);
    FMDBQuickCheck([dbPool countOfCheckedOutDatabases] == 0);
        
    NSError *err = [dbPool inSavePoint:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1006]];
    }];
    
    FMDBQuickCheck(!err);
    
    {
        
        err = [dbPool inSavePoint:^(FMDatabase *adb, BOOL *rollback) {
            FMDBQuickCheck(![adb hadError]);
            [adb executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1009]];
            
            [adb inSavePoint:^(BOOL *rollback) {
                FMDBQuickCheck(([adb executeUpdate:@"insert into easy values (?)", [NSNumber numberWithInt:1010]]));
                *rollback = YES;
            }];
        }];
        
        
        FMDBQuickCheck(!err);
        
        [dbPool inDatabase:^(FMDatabase *db) {
            
            
            FMResultSet *rs2 = [db executeQuery:@"select * from easy where a = ?", [NSNumber numberWithInt:1009]];
            FMDBQuickCheck([rs2 next]);
            FMDBQuickCheck(![rs2 next]); // close it out.
            
            rs2 = [db executeQuery:@"select * from easy where a = ?", [NSNumber numberWithInt:1010]];
            FMDBQuickCheck(![rs2 next]);
        }];
        
        
    }
    
    {
        
        [dbPool inDatabase:^(FMDatabase *db) {
            [db executeUpdate:@"create table likefoo (foo text)"];
            [db executeUpdate:@"insert into likefoo values ('hi')"];
            [db executeUpdate:@"insert into likefoo values ('hello')"];
            [db executeUpdate:@"insert into likefoo values ('not')"];
            
            int count = 0;
            FMResultSet *rsl = [db executeQuery:@"select * from likefoo where foo like 'h%'"];
            while ([rsl next]) {
                count++;
            }
            
            FMDBQuickCheck(count == 2);
            
            count = 0;
            rsl = [db executeQuery:@"select * from likefoo where foo like ?", @"h%"];
            while ([rsl next]) {
                count++;
            }
            
            FMDBQuickCheck(count == 2);
            
        }];
    }
    
    
    {
        
        int ops = 128;
        
        dispatch_queue_t dqueue = dispatch_get_global_queue(0, DISPATCH_QUEUE_PRIORITY_HIGH);
        
        dispatch_apply(ops, dqueue, ^(size_t nby) {
            
            // just mix things up a bit for demonstration purposes.
            if (nby % 2 == 1) {
                
                [NSThread sleepForTimeInterval:.1];
            }
            
            [dbPool inDatabase:^(FMDatabase *db) {
                NSLog(@"Starting query  %ld", nby);
                
                FMResultSet *rsl = [db executeQuery:@"select * from likefoo where foo like 'h%'"];
                while ([rsl next]) {
                    if (nby % 3 == 1) {
                        [NSThread sleepForTimeInterval:.05];
                    }
                }
                
                NSLog(@"Ending query    %ld", nby);
            }];
        });
        
        NSLog(@"Number of open databases after crazy gcd stuff: %ld", [dbPool countOfOpenDatabases]);
    }
    
    
    // if you want to see a deadlock, just uncomment this line and run:
    //#define ONLY_USE_THE_POOL_IF_YOU_ARE_DOING_READS_OTHERWISE_YOULL_DEADLOCK_USE_FMDATABASEQUEUE_INSTEAD 1
#ifdef ONLY_USE_THE_POOL_IF_YOU_ARE_DOING_READS_OTHERWISE_YOULL_DEADLOCK_USE_FMDATABASEQUEUE_INSTEAD
    {
        
        int ops = 16;
        
        dispatch_queue_t dqueue = dispatch_get_global_queue(0, DISPATCH_QUEUE_PRIORITY_HIGH);
        
        dispatch_apply(ops, dqueue, ^(size_t nby) {
            
            // just mix things up a bit for demonstration purposes.
            if (nby % 2 == 1) {
                [NSThread sleepForTimeInterval:.1];
                
                [dbPool inTransaction:^(FMDatabase *db, BOOL *rollback) {
                    NSLog(@"Starting query  %ld", nby);
                    
                    FMResultSet *rsl = [db executeQuery:@"select * from likefoo where foo like 'h%'"];
                    while ([rsl next]) {
                        ;// whatever.
                    }
                    
                    NSLog(@"Ending query    %ld", nby);
                }];
                
            }
            
            if (nby % 3 == 1) {
                [NSThread sleepForTimeInterval:.1];
            }
            
            [dbPool inTransaction:^(FMDatabase *db, BOOL *rollback) {
                NSLog(@"Starting update %ld", nby);
                [db executeUpdate:@"insert into likefoo values ('1')"];
                [db executeUpdate:@"insert into likefoo values ('2')"];
                [db executeUpdate:@"insert into likefoo values ('3')"];
                NSLog(@"Ending update   %ld", nby);
            }];
        });
        
        [dbPool releaseAllDatabases];
        
        [dbPool inDatabase:^(FMDatabase *db) {
            FMDBQuickCheck([db executeUpdate:@"insert into likefoo values ('1')"]);
        }];
    }
#endif

}
