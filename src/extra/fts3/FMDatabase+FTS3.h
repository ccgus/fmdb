//
//  FMDatabase+FTS3.h
//  fmdb
//
//  Created by Andrew on 3/27/14.
//  Copyright (c) 2014 Andrew Goodale. All rights reserved.
//

#import "FMDatabase.h"

/**
 Names of commands that can be issued against an FTS table.
 */
extern NSString *const kFTSCommandOptimize;        // "optimize"
extern NSString *const kFTSCommandRebuild;         // "rebuild"
extern NSString *const kFTSCommandIntegrityCheck;  // "integrity-check"
extern NSString *const kFTSCommandMerge;           // "merge=%u,%u"
extern NSString *const kFTSCommandAutoMerge;       // "automerge=%u"

@protocol FMTokenizerDelegate;

/**
  This category provides methods to access the FTS3 extensions in SQLite.
 */
@interface FMDatabase (FTS3)

/**
 Register a delegate implementation in the global table. This should be used when using a single tokenizer.
 */
+ (void)registerTokenizer:(id<FMTokenizerDelegate>)tokenizer;

/**
 Register a delegate implementation in the global table. The key should be used
 as a parameter when creating the table.
 */
+ (void)registerTokenizer:(id<FMTokenizerDelegate>)tokenizer withKey:(NSString *)key;

/**
 Calls the `fts3_tokenizer()` function on this database, installing tokenizer module with the 'fmdb' name.
 */
- (BOOL)installTokenizerModule;

/**
 Calls the `fts3_tokenizer()` function on this database, installing the tokenizer module with specified name.
 */
- (BOOL)installTokenizerModuleWithName:(NSString *)name;

/**
 Runs a "special command" for FTS3/FTS4 tables.
 */
- (BOOL)issueCommand:(NSString *)command forTable:(NSString *)tableName;

@end

#pragma mark

/* Extend this structure with your own custom cursor data */
typedef struct FMTokenizerCursor
{
    void       *tokenizer;      /* Internal SQLite reference */
    CFStringRef inputString;    /* The input text being tokenized */
    CFRange     currentRange;   /* The current offset within `inputString` */
    CFStringRef tokenString;    /* The contents of the current token */
    CFTypeRef   userObject;     /* Additional state for the cursor */
    int         tokenIndex;     /* Index of next token to be returned */
    UInt8       outputBuf[128]; /* Result for SQLite */
} FMTokenizerCursor;

@protocol FMTokenizerDelegate

- (void)openTokenizerCursor:(FMTokenizerCursor *)cursor;

- (BOOL)nextTokenForCursor:(FMTokenizerCursor *)cursor;

- (void)closeTokenizerCursor:(FMTokenizerCursor *)cursor;

@end

#pragma mark

/**
 The container of offset information.
 */
@interface FMTextOffsets : NSObject

- (instancetype)initWithDBOffsets:(const char *)offsets;

/**
 Enumerate each set of offsets in the result. The column number can be turned into a column name
 using `[FMResultSet columnNameForIndex:]`. The `matchRange` is in UTF-8 byte positions, so it must be 
 modified to use with `NSString` data.
 */
- (void)enumerateWithBlock:(void (^)(NSInteger columnNumber, NSInteger termNumber, NSRange matchRange))block;

@end

/**
 A category that adds support for the encoded data returned by FTS3 functions.
 */
@interface FMResultSet (FTS3)

/**
 Returns a structure containing values from the `offsets()` function. Make sure the column index corresponds
 to the column index in the SQL query.
 
 @param columnIdx Zero-based index for column.
 
 @return `FMTextOffsets` structure.
 */
- (FMTextOffsets *)offsetsForColumnIndex:(int)columnIdx;

@end
