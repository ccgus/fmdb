//
//  FMDatabase+FTS3.m
//  fmdb
//
//  Created by Andrew on 3/27/14.
//  Copyright (c) 2014 Andrew Goodale. All rights reserved.
//

#import "FMDatabase+FTS3.h"
#import "fts3_tokenizer.h"

NSString *const kFTSCommandOptimize = @"optimize";
NSString *const kFTSCommandRebuild  = @"rebuild";
NSString *const kFTSCommandIntegrityCheck = @"integrity-check";
NSString *const kFTSCommandMerge = @"merge=%u,%u";
NSString *const kFTSCommandAutoMerge = @"automerge=%u";

/* I know this is an evil global, but we need to be able to map names to implementations. */
static NSMapTable *g_delegateMap = nil;

/*
 ** Class derived from sqlite3_tokenizer
 */
typedef struct FMDBTokenizer
{
    sqlite3_tokenizer base;
    id<FMTokenizerDelegate> __unsafe_unretained delegate;
} FMDBTokenizer;

/*
 ** Create a new tokenizer instance.
 */
static int FMDBTokenizerCreate(int argc, const char * const *argv, sqlite3_tokenizer **ppTokenizer)
{
    NSCParameterAssert(argc > 0);   // Check that the name of the tokenizer is set in CREATE VIRTUAL TABLE
    
    FMDBTokenizer *tokenizer = (FMDBTokenizer *) sqlite3_malloc(sizeof(FMDBTokenizer));
    
    if (tokenizer == NULL) {
        return SQLITE_NOMEM;
    }
    
    memset(tokenizer, 0, sizeof(*tokenizer));
    tokenizer->delegate = [g_delegateMap objectForKey:[NSString stringWithUTF8String:argv[0]]];
    
    *ppTokenizer = &tokenizer->base;
    return SQLITE_OK;
}

/*
 ** Destroy a tokenizer
 */
static int FMDBTokenizerDestroy(sqlite3_tokenizer *pTokenizer)
{
    sqlite3_free(pTokenizer);
    return SQLITE_OK;
}

/*
 ** Prepare to begin tokenizing a particular string.  The input
 ** string to be tokenized is zInput[0..nInput-1].  A cursor
 ** used to incrementally tokenize this string is returned in
 ** *ppCursor.
 */
static int FMDBTokenizerOpen(sqlite3_tokenizer *pTokenizer,         /* The tokenizer */
                             const char *pInput, int nBytes,        /* String to be tokenized */
                             sqlite3_tokenizer_cursor **ppCursor)   /* OUT: Tokenization cursor */
{
    FMDBTokenizer *tokenizer = (FMDBTokenizer *)pTokenizer;
    FMTokenizerCursor *cursor = (FMTokenizerCursor *)sqlite3_malloc(sizeof(FMTokenizerCursor));
    
    if (cursor == NULL) {
        return SQLITE_NOMEM;
    }
    
    if (pInput == NULL || pInput[0] == '\0') {
        cursor->inputString = CFRetain(CFSTR(""));
    } else {
        nBytes = (nBytes < 0) ? (int) strlen(pInput) : nBytes;
        cursor->inputString = CFStringCreateWithBytesNoCopy(NULL, (const UInt8 *)pInput, nBytes,
                                                            kCFStringEncodingUTF8, false, kCFAllocatorNull);
    }
    
    cursor->currentRange = CFRangeMake(0, 0);
    cursor->tokenIndex = 0;
    cursor->tokenString = NULL;
    cursor->userObject = NULL;
    cursor->outputBuf[0] = '\0';
        
    [tokenizer->delegate openTokenizerCursor:cursor];

    *ppCursor = (sqlite3_tokenizer_cursor *)cursor;
    return SQLITE_OK;
}

/*
 ** Close a tokenization cursor previously opened by a call to
 ** FMDBTokenizerOpen() above.
 */
static int FMDBTokenizerClose(sqlite3_tokenizer_cursor *pCursor)
{
    FMTokenizerCursor *cursor = (FMTokenizerCursor *)pCursor;
    FMDBTokenizer *tokenizer = (FMDBTokenizer *)cursor->tokenizer;
    
    [tokenizer->delegate closeTokenizerCursor:cursor];
    
    if (cursor->userObject) {
        CFRelease(cursor->userObject);
    }
    if (cursor->tokenString) {
        CFRelease(cursor->tokenString);
    }
    
    CFRelease(cursor->inputString);
    sqlite3_free(cursor);
    
    return SQLITE_OK;
}


/*
 ** Extract the next token from a tokenization cursor.  The cursor must
 ** have been opened by a prior call to FMDBTokenizerOpen().
 */
static int FMDBTokenizerNext(sqlite3_tokenizer_cursor *pCursor,  /* Cursor returned by Open */
                             const char **pzToken,               /* OUT: *pzToken is the token text */
                             int *pnBytes,                       /* OUT: Number of bytes in token */
                             int *piStartOffset,                 /* OUT: Starting offset of token */
                             int *piEndOffset,                   /* OUT: Ending offset of token */
                             int *piPosition)                    /* OUT: Position integer of token */
{
    FMTokenizerCursor *cursor = (FMTokenizerCursor *)pCursor;
    FMDBTokenizer *tokenizer = (FMDBTokenizer *)cursor->tokenizer;
    
    if ([tokenizer->delegate nextTokenForCursor:cursor]) {
        return SQLITE_DONE;
    }
    
    CFRange range = CFRangeMake(0, CFStringGetLength(cursor->tokenString));
    CFIndex usedBytes = 0;
    
    CFStringGetBytes(cursor->tokenString, range, kCFStringEncodingUTF8, '?', false,
                     cursor->outputBuf, sizeof(cursor->outputBuf), &usedBytes);
    
    *pzToken = (char *) cursor->outputBuf;
    *pnBytes = (int) usedBytes;
    *piStartOffset = (int) cursor->currentRange.location;
    *piEndOffset = (int) (cursor->currentRange.location + cursor->currentRange.length);
    *piPosition = cursor->tokenIndex++;
    
    return SQLITE_OK;
}


/*
 ** The set of routines that bridge to the tokenizer delegate.
 */
static const sqlite3_tokenizer_module FMDBTokenizerModule =
{
    0,
    FMDBTokenizerCreate,
    FMDBTokenizerDestroy,
    FMDBTokenizerOpen,
    FMDBTokenizerClose,
    FMDBTokenizerNext
};

#pragma mark

@implementation FMDatabase (FTS3)

+ (void)registerTokenizer:(id<FMTokenizerDelegate>)tokenizer withName:(NSString *)name
{
    NSParameterAssert(tokenizer);
    NSParameterAssert([name length]);
    
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        g_delegateMap = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsCopyIn
                                              valueOptions:NSPointerFunctionsWeakMemory];
    });
    
    [g_delegateMap setObject:tokenizer forKey:name];
}

- (BOOL)installTokenizerModule
{
    const sqlite3_tokenizer_module *module = &FMDBTokenizerModule;
    NSData *tokenizerData = [NSData dataWithBytes:&module  length:sizeof(module)];
    
    FMResultSet *results = [self executeQuery:@"SELECT fts3_tokenizer('fmdb', ?)", tokenizerData];
    
    if ([results next]) {
        [results close];
        return YES;
    }
    
    return NO;
}

- (BOOL)issueCommand:(NSString *)command forTable:(NSString *)tableName
{
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO %1$@(%1$@) VALUES (?)", tableName];
    
    return [self executeUpdate:sql, command];
}

@end

#pragma mark

@implementation FMResultSet (FTS3)

- (FMTextOffsets)offsetsForColumnIndex:(int)columnIdx
{
    // The offsets() value is a space separated string of 4 integers
    uint32_t offsetInts[4];
    const char *rawOffsets = (const char *)sqlite3_column_text([_statement statement], columnIdx);
    
    sscanf(rawOffsets, "%u %u %u %u", &offsetInts[0], &offsetInts[1], &offsetInts[2], &offsetInts[3]);
    
    FMTextOffsets offsets = { offsetInts[0], offsetInts[1], NSMakeRange(offsetInts[2], offsetInts[3]) };
    return offsets;
}

@end
