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
	
The `?` character is recognized by SQLite as a placeholder for a value to be inserted.  The execution methods all accept a variable number of arguments (or a representation of those arguments, such as an `NSArray`, `NSDictionary`, or a `va_list`), which are properly escaped for you.

Alternatively, you may use named parameters syntax:

	INSERT INTO myTable VALUES (:id, :name, :value)
	
The parameters *must* start with a colon. SQLite itself supports other characters, but internally the Dictionary keys are prefixed with a colon, do **not** include the colon in your dictionary keys.

	NSDictionary *argsDict = [NSDictionary dictionaryWithObjectsAndKeys:@"My Name", @"name", nil];
	[db executeUpdate:@"INSERT INTO myTable (name) VALUES (:name)" withArgumentsInDictionary:argsDict];
	
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

## History

The history and changes are availbe on its [GitHub page](https://github.com/ccgus/fmdb) and are summarized in the "CHANGES_AND_TODO_LIST.txt" file.

## Contributors

The contributors to FMDB are contained in the "Contributors.txt" file.

## License

The license for FMDB is contained in the "License.txt" file.