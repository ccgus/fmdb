//
//  FMDatabasePrivate.h
//  fmdb
//
//  Created by Robert Ryan on 3/28/15.
//
//

#ifndef fmdb_FMDatabasePrivate_h
#define fmdb_FMDatabasePrivate_h

#import <sqlite3.h>

@class FMDatabase;
@class FMStatement;

@interface FMDatabase (Private)

/** SQLite sqlite3
 
 @see [`sqlite3`](http://www.sqlite.org/c3ref/sqlite3.html)
 */

@property (nonatomic, assign, readonly) sqlite3 *db;

@end

@interface FMStatement (Private)

/** SQLite sqlite3_stmt
 
 @see [`sqlite3_stmt`](http://www.sqlite.org/c3ref/stmt.html)
 */

@property (nonatomic, assign) sqlite3_stmt *statement;

@end

#endif
