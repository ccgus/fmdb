# FMDB v2.6.2

This is an Objective-C wrapper around SQLite: http://sqlite.org/

## The FMDB Mailing List:
http://groups.google.com/group/fmdb

## Read the SQLite FAQ:
http://www.sqlite.org/faq.html

Since FMDB is built on top of SQLite, you're going to want to read this page top to bottom at least once.  And while you're there, make sure to bookmark the SQLite Documentation page: http://www.sqlite.org/docs.html

## Contributing
Do you have an awesome idea that deserves to be in FMDB?  You might consider pinging ccgus first to make sure he hasn't already ruled it out for some reason.  Otherwise pull requests are great, and make sure you stick to the local coding conventions.  However, please be patient and if you haven't heard anything from ccgus for a week or more, you might want to send a note asking what's up.

## CocoaPods

[![Dependency Status](https://www.versioneye.com/objective-c/fmdb/2.3/badge.svg?style=flat)](https://www.versioneye.com/objective-c/fmdb/2.3)
[![Reference Status](https://www.versioneye.com/objective-c/fmdb/reference_badge.svg?style=flat)](https://www.versioneye.com/objective-c/fmdb/references)

FMDB can be installed using [CocoaPods](https://cocoapods.org/).

```
pod 'FMDB'
# pod 'FMDB/FTS'   # FMDB with FTS
# pod 'FMDB/standalone'   # FMDB with latest SQLite amalgamation source
# pod 'FMDB/standalone/FTS'   # FMDB with latest SQLite amalgamation source and FTS
# pod 'FMDB/SQLCipher'   # FMDB with SQLCipher
```

**If using FMDB with [SQLCipher](https://www.zetetic.net/sqlcipher/) you must use the FMDB/SQLCipher subspec. The FMDB/SQLCipher subspec declares SQLCipher as a dependency, allowing FMDB to be compiled with the `-DSQLITE_HAS_CODEC` flag.**

## FMDB Class Reference:
http://ccgus.github.io/fmdb/html/index.html

## Automatic Reference Counting (ARC) or Manual Memory Management?
You can use either style in your Cocoa project.  FMDB will figure out which you are using at compile time and do the right thing.

## Usage
There are three main classes in FMDB:

1. `FMDatabase` - Represents a single SQLite database.  Used for executing SQL statements.
2. `FMResultSet` - Represents the results of executing a query on an `FMDatabase`.
3. `FMDatabaseQueue` - If you're wanting to perform queries and updates on multiple threads, you'll want to use this class.  It's described in the "Thread Safety" section below.

### Database Creation
An `FMDatabase` is created with a path to a SQLite database file.  This path can be one of these three:

1. A file system path.  The file does not have to exist on disk.  If it does not exist, it is created for you.
2. An empty string (`@""`).  An empty database is created at a temporary location.  This database is deleted with the `FMDatabase` connection is closed.
3. `NULL`.  An in-memory database is created.  This database will be destroyed with the `FMDatabase` connection is closed.

(For more information on temporary and in-memory databases, read the sqlite documentation on the subject: http://www.sqlite.org/inmemorydb.html)

```objc
FMDatabase *db = [FMDatabase databaseWithPath:@"/tmp/tmp.db"];
```

### Opening

Before you can interact with the database, it must be opened.  Opening fails if there are insufficient resources or permissions to open and/or create the database.

```objc
if (![db open]) {
    [db release];
    return;
}
```

### Executing Updates

Any sort of SQL statement which is not a `SELECT` statement qualifies as an update.  This includes `CREATE`, `UPDATE`, `INSERT`, `ALTER`, `COMMIT`, `BEGIN`, `DETACH`, `DELETE`, `DROP`, `END`, `EXPLAIN`, `VACUUM`, and `REPLACE` statements (plus many more).  Basically, if your SQL statement does not begin with `SELECT`, it is an update statement.

Executing updates returns a single value, a `BOOL`.  A return value of `YES` means the update was successfully executed, and a return value of `NO` means that some error was encountered.  You may invoke the `-lastErrorMessage` and `-lastErrorCode` methods to retrieve more information.

### Executing Queries

A `SELECT` statement is a query and is executed via one of the `-executeQuery...` methods.

Executing queries returns an `FMResultSet` object if successful, and `nil` upon failure.  You should use the `-lastErrorMessage` and `-lastErrorCode` methods to determine why a query failed.

In order to iterate through the results of your query, you use a `while()` loop.  You also need to "step" from one record to the other.  With FMDB, the easiest way to do that is like this:

```objc
FMResultSet *s = [db executeQuery:@"SELECT * FROM myTable"];
while ([s next]) {
    //retrieve values for each record
}
```

You must always invoke `-[FMResultSet next]` before attempting to access the values returned in a query, even if you're only expecting one:

```objc
FMResultSet *s = [db executeQuery:@"SELECT COUNT(*) FROM myTable"];
if ([s next]) {
    int totalCount = [s intForColumnIndex:0];
}
```

`FMResultSet` has many methods to retrieve data in an appropriate format:

- `intForColumn:`
- `longForColumn:`
- `longLongIntForColumn:`
- `boolForColumn:`
- `doubleForColumn:`
- `stringForColumn:`
- `dateForColumn:`
- `dataForColumn:`
- `dataNoCopyForColumn:`
- `UTF8StringForColumnName:`
- `objectForColumnName:`

Each of these methods also has a `{type}ForColumnIndex:` variant that is used to retrieve the data based on the position of the column in the results, as opposed to the column's name.

Typically, there's no need to `-close` an `FMResultSet` yourself, since that happens when either the result set is deallocated, or the parent database is closed.

### Closing

When you have finished executing queries and updates on the database, you should `-close` the `FMDatabase` connection so that SQLite will relinquish any resources it has acquired during the course of its operation.

```objc
[db close];
```

### Transactions

`FMDatabase` can begin and commit a transaction by invoking one of the appropriate methods or executing a begin/end transaction statement.

### Multiple Statements and Batch Stuff

You can use `FMDatabase`'s executeStatements:withResultBlock: to do multiple statements in a string:

```objc
NSString *sql = @"create table bulktest1 (id integer primary key autoincrement, x text);"
                 "create table bulktest2 (id integer primary key autoincrement, y text);"
                 "create table bulktest3 (id integer primary key autoincrement, z text);"
                 "insert into bulktest1 (x) values ('XXX');"
                 "insert into bulktest2 (y) values ('YYY');"
                 "insert into bulktest3 (z) values ('ZZZ');";

success = [db executeStatements:sql];

sql = @"select count(*) as count from bulktest1;"
       "select count(*) as count from bulktest2;"
       "select count(*) as count from bulktest3;";

success = [self.db executeStatements:sql withResultBlock:^int(NSDictionary *dictionary) {
    NSInteger count = [dictionary[@"count"] integerValue];
    XCTAssertEqual(count, 1, @"expected one record for dictionary %@", dictionary);
    return 0;
}];
```

### Data Sanitization

When providing a SQL statement to FMDB, you should not attempt to "sanitize" any values before insertion.  Instead, you should use the standard SQLite binding syntax:

```sql
INSERT INTO myTable VALUES (?, ?, ?, ?)
```

The `?` character is recognized by SQLite as a placeholder for a value to be inserted.  The execution methods all accept a variable number of arguments (or a representation of those arguments, such as an `NSArray`, `NSDictionary`, or a `va_list`), which are properly escaped for you.

And, to use that SQL with the `?` placeholders from Objective-C:

```objc
NSInteger identifier = 42;
NSString *name = @"Liam O'Flaherty (\"the famous Irish author\")";
NSDate *date = [NSDate date];
NSString *comment = nil;

BOOL success = [db executeUpdate:@"INSERT INTO authors (identifier, name, date, comment) VALUES (?, ?, ?, ?)", @(identifier), name, date, comment ?: [NSNull null]];
if (!success) {
    NSLog(@"error = %@", [db lastErrorMessage]);
}
```

> **Note:** Fundamental data types, like the `NSInteger` variable `identifier`, should be as a `NSNumber` objects, achieved by using the `@` syntax, shown above. Or you can use the `[NSNumber numberWithInt:identifier]` syntax, too.
>
> Likewise, SQL `NULL` values should be inserted as `[NSNull null]`. For example, in the case of `comment` which might be `nil` (and is in this example), you can use the `comment ?: [NSNull null]` syntax, which will insert the string if `comment` is not `nil`, but will insert `[NSNull null]` if it is `nil`.

In Swift, you would use `executeUpdate(values:)`, which not only is a concise Swift syntax, but also `throws` errors for proper Swift 2 error handling:

```swift
do {
    let identifier = 42
    let name = "Liam O'Flaherty (\"the famous Irish author\")"
    let date = NSDate()
    let comment: String? = nil

    try db.executeUpdate("INSERT INTO authors (identifier, name, date, comment) VALUES (?, ?, ?, ?)", values: [identifier, name, date, comment ?? NSNull()])
} catch {
    print("error = \(error)")
}
```

> **Note:** In Swift, you don't have to wrap fundamental numeric types like you do in Objective-C. But if you are going to insert an optional string, you would probably use the `comment ?? NSNull()` syntax (i.e., if it is `nil`, use `NSNull`, otherwise use the string).

Alternatively, you may use named parameters syntax:

```sql
INSERT INTO authors (identifier, name, date, comment) VALUES (:identifier, :name, :date, :comment)
```

The parameters *must* start with a colon. SQLite itself supports other characters, but internally the dictionary keys are prefixed with a colon, do **not** include the colon in your dictionary keys.

```objc
NSDictionary *arguments = @{@"identifier": @(identifier), @"name": name, @"date": date, @"comment": comment ?: [NSNull null]};
BOOL success = [db executeUpdate:@"INSERT INTO authors (identifier, name, date, comment) VALUES (:identifier, :name, :date, :comment)" withParameterDictionary:arguments];
if (!success) {
    NSLog(@"error = %@", [db lastErrorMessage]);
}
```

The key point is that one should not use `NSString` method `stringWithFormat` to manually insert values into the SQL statement, itself. Nor should one Swift string interpolation to insert values into the SQL. Use `?` placeholders for values to be inserted into the database (or used in `WHERE` clauses in `SELECT` statements).

<h2 id="threads">Using FMDatabaseQueue and Thread Safety.</h2>

Using a single instance of `FMDatabase` from multiple threads at once is a bad idea.  It has always been OK to make a `FMDatabase` object *per thread*.  Just don't share a single instance across threads, and definitely not across multiple threads at the same time.  Bad things will eventually happen and you'll eventually get something to crash, or maybe get an exception, or maybe meteorites will fall out of the sky and hit your Mac Pro.  *This would suck*.

**So don't instantiate a single `FMDatabase` object and use it across multiple threads.**

Instead, use `FMDatabaseQueue`. Instantiate a single `FMDatabaseQueue` and use it across multiple threads. The `FMDatabaseQueue` object will synchronize and coordinate access across the multiple threads. Here's how to use it:

First, make your queue.

```objc
FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:aPath];
```

Then use it like so:


```objc
[queue inDatabase:^(FMDatabase *db) {
    [db executeUpdate:@"INSERT INTO myTable VALUES (?)", @1];
    [db executeUpdate:@"INSERT INTO myTable VALUES (?)", @2];
    [db executeUpdate:@"INSERT INTO myTable VALUES (?)", @3];

    FMResultSet *rs = [db executeQuery:@"select * from foo"];
    while ([rs next]) {
        …
    }
}];
```

An easy way to wrap things up in a transaction can be done like this:

```objc
[queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
    [db executeUpdate:@"INSERT INTO myTable VALUES (?)", @1];
    [db executeUpdate:@"INSERT INTO myTable VALUES (?)", @2];
    [db executeUpdate:@"INSERT INTO myTable VALUES (?)", @3];

    if (whoopsSomethingWrongHappened) {
        *rollback = YES;
        return;
    }
    // etc…
    [db executeUpdate:@"INSERT INTO myTable VALUES (?)", @4];
}];
```

The Swift equivalent would be:

```swift
queue.inTransaction { db, rollback in
    do {
        try db.executeUpdate("INSERT INTO myTable VALUES (?)", values: [1])
        try db.executeUpdate("INSERT INTO myTable VALUES (?)", values: [2])
        try db.executeUpdate("INSERT INTO myTable VALUES (?)", values: [3])

        if whoopsSomethingWrongHappened {
            rollback.memory = true
            return
        }

        try db.executeUpdate("INSERT INTO myTable VALUES (?)", values: [4])
    } catch {
        rollback.memory = true
        print(error)
    }
}
```

`FMDatabaseQueue` will run the blocks on a serialized queue (hence the name of the class).  So if you call `FMDatabaseQueue`'s methods from multiple threads at the same time, they will be executed in the order they are received.  This way queries and updates won't step on each other's toes, and every one is happy.

**Note:** The calls to `FMDatabaseQueue`'s methods are blocking.  So even though you are passing along blocks, they will **not** be run on another thread.

## Making custom sqlite functions, based on blocks.

You can do this!  For an example, look for `-makeFunctionNamed:` in main.m

## Swift

You can use FMDB in Swift projects too.

To do this, you must:

1. Copy the relevant `.m` and `.h` files from the FMDB `src` folder into your project.

 You can copy all of them (which is easiest), or only the ones you need. Likely you will need [`FMDatabase`](http://ccgus.github.io/fmdb/html/Classes/FMDatabase.html) and [`FMResultSet`](http://ccgus.github.io/fmdb/html/Classes/FMResultSet.html) at a minimum. [`FMDatabaseAdditions`](http://ccgus.github.io/fmdb/html/Categories/FMDatabase+FMDatabaseAdditions.html) provides some very useful convenience methods, so you will likely want that, too. If you are doing multithreaded access to a database, [`FMDatabaseQueue`](http://ccgus.github.io/fmdb/html/Classes/FMDatabaseQueue.html) is quite useful, too. If you choose to not copy all of the files from the `src` directory, though, you may want to update `FMDB.h` to only reference the files that you included in your project.

 Note, if you're copying all of the files from the `src` folder into to your project (which is recommended), you may want to drag the individual files into your project, not the folder, itself, because if you drag the folder, you won't be prompted to add the bridging header (see next point).

2. If prompted to create a "bridging header", you should do so. If not prompted and if you don't already have a bridging header, add one.

 For more information on bridging headers, see [Swift and Objective-C in the Same Project](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/BuildingCocoaApps/MixandMatch.html#//apple_ref/doc/uid/TP40014216-CH10-XID_76).

3. In your bridging header, add a line that says:
    ```objc
    #import "FMDB.h"
    ```

4. Use the variations of `executeQuery` and `executeUpdate` with the `sql` and `values` parameters with `try` pattern, as shown below. These renditions of `executeQuery` and `executeUpdate` both `throw` errors in true Swift 2 fashion.

If you do the above, you can then write Swift code that uses `FMDatabase`. For example:

```swift
let documents = try! NSFileManager.defaultManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
let fileURL = documents.URLByAppendingPathComponent("test.sqlite")

let database = FMDatabase(path: fileURL.path)

if !database.open() {
    print("Unable to open database")
    return
}

do {
    try database.executeUpdate("create table test(x text, y text, z text)", values: nil)
    try database.executeUpdate("insert into test (x, y, z) values (?, ?, ?)", values: ["a", "b", "c"])
    try database.executeUpdate("insert into test (x, y, z) values (?, ?, ?)", values: ["e", "f", "g"])

    let rs = try database.executeQuery("select x, y, z from test", values: nil)
    while rs.next() {
        let x = rs.stringForColumn("x")
        let y = rs.stringForColumn("y")
        let z = rs.stringForColumn("z")
        print("x = \(x); y = \(y); z = \(z)")
    }
} catch let error as NSError {
    print("failed: \(error.localizedDescription)")
}

database.close()
```

## History

The history and changes are availbe on its [GitHub page](https://github.com/ccgus/fmdb) and are summarized in the "CHANGES_AND_TODO_LIST.txt" file.

## Contributors

The contributors to FMDB are contained in the "Contributors.txt" file.

## Additional projects using FMDB, which might be interesting to the discerning developer.

 * FMDBMigrationManager, A SQLite schema migration management system for FMDB: https://github.com/layerhq/FMDBMigrationManager
 * FCModel, An alternative to Core Data for people who like having direct SQL access: https://github.com/marcoarment/FCModel

## Quick notes on FMDB's coding style

Spaces, not tabs.  Square brackets, not dot notation.  Look at what FMDB already does with curly brackets and such, and stick to that style.

## Reporting bugs

Reduce your bug down to the smallest amount of code possible.  You want to make it super easy for the developers to see and reproduce your bug.  If it helps, pretend that the person who can fix your bug is active on shipping 3 major products, works on a handful of open source projects, has a newborn baby, and is generally very very busy.

And we've even added a template function to main.m (FMDBReportABugFunction) in the FMDB distribution to help you out:

* Open up fmdb project in Xcode.
* Open up main.m and modify the FMDBReportABugFunction to reproduce your bug.
    * Setup your table(s) in the code.
    * Make your query or update(s).
    * Add some assertions which demonstrate the bug.

Then you can bring it up on the FMDB mailing list by showing your nice and compact FMDBReportABugFunction, or you can report the bug via the github FMDB bug reporter.

**Optional:**

Figure out where the bug is, fix it, and send a patch in or bring that up on the mailing list.  Make sure all the other tests run after your modifications.

## Support

The support channels for FMDB are the mailing list (see above), filing a bug here, or maybe on Stack Overflow.  So that is to say, support is provided by the community and on a voluntary basis.

FMDB development is overseen by Gus Mueller of Flying Meat.  If FMDB been helpful to you, consider purchasing an app from FM or telling all your friends about it.

## License

The license for FMDB is contained in the "License.txt" file.

If you happen to come across either Gus Mueller or Rob Ryan in a bar, you might consider purchasing a drink of their choosing if FMDB has been useful to you.

(The drink is for them of course, shame on you for trying to keep it.)
