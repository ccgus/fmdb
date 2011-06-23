#import <Foundation/Foundation.h>
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

#define FMDBQuickCheck(SomeBool) { if (!(SomeBool)) { NSLog(@"Failure on line %d", __LINE__); return 123; } }

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    // delete the old db.
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:@"/tmp/tmp.db" error:nil];
    
    FMDatabase *db = [FMDatabase databaseWithPath:@"/tmp/tmp.db"];
    
    {
		// -------------------------------------------------------------------------------
		// Un-opened database check.		
		FMDBQuickCheck([db executeQuery:@"select * from table"] == nil);
		NSLog(@"%d: %@", [db lastErrorCode], [db lastErrorMessage]);
	}
    
    
    if (![db open]) {
        NSLog(@"Could not open db.");
        [pool release];
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
    FMDBQuickCheck(![db update:@"blah blah blah" error:&err bind:nil]);
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
    
    [db setBusyRetryTimeout:50000];
    
    FMDatabase *newDb = [FMDatabase databaseWithPath:@"/tmp/tmp.db"];
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
    NSLog(@"That was version %@ of sqlite", [FMDatabase sqliteLibVersion]);
    
    
    [db close];
    
    [pool release];
    return 0;
}
