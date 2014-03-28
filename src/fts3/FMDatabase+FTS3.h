//
//  FMDatabase+FTS3.h
//  fmdb
//
//  Created by Andrew on 3/27/14.
//  Copyright (c) 2014 Andrew Goodale. All rights reserved.
//

#import "FMDatabase.h"

@protocol FMTokenizerDelegate;

@interface FMDatabase (FTS3)

- (BOOL)registerTokenizer:(id<FMTokenizerDelegate>)tokenizer withName:(NSString *)name;

@end

#pragma mark

/* Extend this structure with your own custom cursor data */
typedef struct FMTokenizerCursor
{
    void       *tokenizer;      /* Internal SQLite reference */
    void       *tempBuffer;     /* Internal temporary memory */
    CFStringRef inputString;    /* The input text being tokenized */
    CFRange     currentRange;   /* The current offset within `inputString` */
    CFStringRef tokenString;    /* The contents of the current token */
    CFTypeRef   userObject;     /* Additional state for the cursor */
    int         tokenIndex;     /* Index of next token to be returned */
} FMTokenizerCursor;

@protocol FMTokenizerDelegate

- (void)openTokenizerCursor:(FMTokenizerCursor *)cursor;

- (BOOL)nextTokenForCursor:(FMTokenizerCursor *)cursor;

- (void)closeTokenizerCursor:(FMTokenizerCursor *)cursor;

@end