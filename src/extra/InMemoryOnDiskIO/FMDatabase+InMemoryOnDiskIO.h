//
//  FMDatabase+InMemoryOnDiskIO.h
//  FMDB
//
//  Created by Peter Carr on 6/12/12.
//
//  I find there is a massive performance hit using an "on-disk" representation when
//  constantly reading from or writing to the DB.  If your machine has sufficient memory, you
//  should get a significant performance boost using an "in-memory" representation.  The FMDB
//  warpper does not contain methods to load an "on-disk" representation into memory and
//  similarly save an "in-memory" representation to disk.  However, SQLite3 has built-in 
//  support for this functionality via its "Backup" API.  Here, we extend the FMBD wrapper
//  to include this functionality.
//
//  http://www.sqlite.org/backup.html

#import "FMDatabase.h"

@interface FMDatabase (InMemoryOnDiskIO)

// Loads an on-disk representation into memory.
- (BOOL)readFromFile:(NSString*)filePath;

// Saves an in-memory representation to disk
- (BOOL)writeToFile:(NSString *)filePath;
@end
