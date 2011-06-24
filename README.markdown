# FMDB

This is an Objective-C wrapper around SQLite: http://sqlite.org/

## Usage

There are two main classes in FMDB:

1. `FMDatabase` - Represents a single SQLite database.  Used for executing SQL statements.
2. `FMResultSet` - Represents the results of executing a query on an `FMDatabase`.

### Database Creation
An `FMDatabase` is created with a path to a SQLite database file.  This path can be one of these three:

1. A file system path.  The file does not have to exist on disk.  If it does not exist, it is created for you.
2. An empty string (`@""`).  An empty database is created at a temporary location.  This database is deleted with the `FMDatabase` connection is closed.
3. `NULL`.  An in-memory database is created.  This database will be destroyed with the `FMDatabase` connection is closed.

	FMDatabase *db = [FMDatabase databaseWithPath:@"/tmp/tmp.db"];
	
### Opening

Before you can interact with the database, it must be opened.  Opening fails if there are insufficient resources or permissions to open and/or create the database.

	if (![db open]) {
		[db release];
		return;
	}
	
### Executing Updates

Any sort of SQL statement which is not a `SELECT` statement qualifies as an update.  This includes `CREATE`, `PRAGMA`, `UPDATE`, `INSERT`, `ALTER`, `COMMIT`, `BEGIN`, `DETACH`, `DELETE`, `DROP`, `END`, `EXPLAIN`, `VACUUM`, and `REPLACE` statements (plus many more).  Basically, if your SQL statement does not begin with `SELECT`, it is an update statement.

Executing updates returns a single value, a `BOOL`.  A return value of `YES` means the update was successfully executed, and a return value of `NO` means that some error was encountered.  If you use the `-[FMDatabase executeUpdate:error:withArgumentsInArray:orVAList:]` method to execute an update, you may supply an `NSError **` that will be filled in if execution fails.  Otherwise you may invoke the `-lastErrorMessage` and `-lastErrorCode` methods to retrieve more information.

### Executing Queries

A `SELECT` statement is a query and is executed via one of the `-executeQuery...` methods.

Executing queries returns an `FMResultSet` object if successful, and `nil` upon failure.  Like executing updates, there is a variant that accepts an `NSError **` parameter.  Otherwise you should use the `-lastErrorMessage` and `-lastErrorCode` methods to determine why a query failed.

In order to iterate through the results of your query, you use a `while()` loop.  You also need to "step" from one record to the other.  With FMDB, the easiest way to do that is like this:

	FMResultSet *s = [db executeQuery:@"SELECT * FROM myTable"];
	while ([s next]) {
		//retrieve values for each record
	}
	
You must always invoke `-[FMResultSet next]` before attempting to access the values returned in a query, even if you're only expecting one:

	FMResultSet *s = [db executeQuery:@"SELECT COUNT(*) FROM myTable"];
	if ([s next]) {
		int totalCount = [s intForColumnIndex:0];
	}
	
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
- `UTF8StringForColumnIndex:`
- `objectForColumn:`

Each of these methods also has a `{type}ForColumnIndex:` variant that is used to retrieve the data based on the position of the column in the results, as opposed to the column's name.

Typically, there's no need to `-close` an `FMResultSet` yourself, since that happens when either the result set is deallocated, or the parent database is closed.

### Closing

When you have finished executing queries and updates on the database, you should `-close` the `FMDatabase` connection so that SQLite will relinquish any resources it has acquired during the course of its operation.

	[db close];
	
### Transactions

`FMDatabase` can begin and commit a transaction by invoking one of the appropriate methods or executing a begin/end transaction statement.

### Data Sanitization

When providing a SQL statement to FMDB, you should not attempt to "sanitize" any values before insertion.  Instead, you should use the standard SQLite binding syntax:

	INSERT INTO myTable VALUES (?, ?, ?)
	
The `?` character is recognized by SQLite as a placeholder for a value to be inserted.  The execution methods all accept a variable number of arguments (or a representation of those arguments, such as an `NSArray` or a `va_list`), which are properly escaped for you.

Thus, you SHOULD NOT do this (or anything like this):

	[db executeUpdate:[NSString stringWithFormat:@"INSERT INTO myTable VALUES (%@)", @"this has \" lots of ' bizarre \" quotes '"]];
	
Instead, you SHOULD do:

	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", @"this has \" lots of ' bizarre \" quotes '"];
	
All arguments provided to the `-executeUpdate:` method (or any of the variants that accept a `va_list` as a parameter) must be objects.  The following will not work (and will result in a crash):

	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", 42];
	
The proper way to insert a number is to box it in an `NSNumber` object:

	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:42]];
	
Alternatively, you can use the `-execute*WithFormat:` variant to use `NSString`-style substitution:

	[db executeUpdateWithFormat:@"INSERT INTO myTable VALUES (%d)", 42];
	
Internally, the `-execute*WithFormat:` methods are properly boxing things for you.  The following percent modifiers are recognized:  `%@`, `%c`, `%s`, `%d`, `%D`, `%i`, `%u`, `%U`, `%hi`, `%hu`, `%qi`, `%qu`, `%f`, `%g`, `%ld`, `%lu`, `%lld`, and `%llu`.  Using a modifier other than those will have unpredictable results.  If, for some reason, you need the `%` character to appear in your SQL statement, you should use `%%`.


<h2 id="threads">Using FMDatabasePool and Thread Safety.</h2>

**Note:** This is preliminary and subject to change.  Consider it experimental, but feel free to try it out and give me feedback.  I'm also not a fan of the some method names I've added (useDatabase:, useTransaction:) - if you've got better ideas for a name, let me know.

Using a single instance of FMDatabase from multiple threads at once is not supported. The Fine Print: It's always been ok to make a FMDatabase object *per thread*.  Just don't share a single instance across threads, and definitely not across multiple threads at the same time.  Bad things will eventually happen and you'll eventually get something to crash, or maybe get an exception, or maybe meteorites will fall out of the sky and hit your Mac Pro.  *This would suck*.

**So don't instantiate a single FMDatabase object and use it across multiple threads.**



Instead, use FMDatabasePool.  It's your friend and it's here to help.  Here's how to use it:


First, make your pool.

	FMDatabasePool *pool = [FMDatabasePool databasePoolWithPath:aPath];

If you just have a single statement- use it like so:

	[[pool db] executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:42]];

The pool's db method will return an instance of FMDatabase that knows it is in a pool.  After it is done with the update, it will place itself back into the pool.

Making a query is similar:
	
	FMResultSet *rs = [[pool db] executeQuery:@"SELECT * FROM myTable"];
	while ([rs next]) {
		//retrieve values for each record
	}

When the result set is exhausted or [rs close] is called, the result set will tell the database it was created from to put itself back into the pool for use later on.

If you'd rather use multiple queries without having to call [pool db] each time, you can grab a database instance, tell it to stay out of the pool, and then tell it to go back in the pool when you're done:

	FMDatabase *db = [[pool db] popFromPool];
	…
	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:1]];
	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:2]];
	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:3]];
	…
	// put the database back in the pool.
	[db pushToPool];

Alternatively, you can use this nifty block based approach:

	[dbPool useDatabase: ^(FMDatabase *aDb) {
		[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:1]];
		[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:2]];
		[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:3]];
	}];

And it will do the right thing.

Starting a transaction will keep the db from going back into the pool automatically:

	FMDatabase *db = [pool db];
	[db beginTransaction];
	
	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:1]];
	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:2]];
	[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:3]];
	
	[db commit]; // or a rollback here would work as well.
 

There is also a block based transaction approach:

	[dbPool useTransaction:^(FMDatabase *db, BOOL *rollback) {
		[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:1]];
		[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:2]];
		[db executeUpdate:@"INSERT INTO myTable VALUES (?)", [NSNumber numberWithInt:3]];
    }];



If you check out a database, but never execute a statement or query, **you need to put it back in the pool yourself**.

	FMDatabase *db = [pool db];
	// lala, don't do anything with the database
	…
	// oh look, I BETTER PUT THE DB BACK IN THE POOL OR ELSE IT IS GOING TO LEAK:
	[db pushToPool];
	
	

## History

The history and changes are availbe on its [GitHub page](https://github.com/ccgus/fmdb) and are summarized in the "CHANGES_AND_TODO_LIST.txt" file.

## Contributors

The contributors to FMDB are contained in the "Contributors.txt" file.

## License

The license for FMDB is contained in the "License.txt" file.