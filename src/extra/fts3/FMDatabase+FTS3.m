//
//  FMDatabase+FTS3.m
//  fmdb
//
//  Created by Andrew on 3/27/14.
//  Copyright (c) 2014 Andrew Goodale. All rights reserved.
//

#import "FMDatabase+FTS3.h"
#import "fts3_tokenizer.h"
#include "sqlite3.h"
NSString *const kFTSCommandOptimize = @"optimize";
NSString *const kFTSCommandRebuild  = @"rebuild";
NSString *const kFTSCommandIntegrityCheck = @"integrity-check";
NSString *const kFTSCommandMerge = @"merge=%u,%u";
NSString *const kFTSCommandAutoMerge = @"automerge=%u";

/* I know this is an evil global, but we need to be able to map names to implementations. */
static NSMapTable *g_delegateMap = nil;

static NSString *kDefaultTokenizerDelegateKey = @"DefaultTokenizerDelegateKey";

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
    FMDBTokenizer *tokenizer = (FMDBTokenizer *) sqlite3_malloc(sizeof(FMDBTokenizer));
    
    if (tokenizer == NULL) {
        return SQLITE_NOMEM;
    }
    
    memset(tokenizer, 0, sizeof(*tokenizer));

    NSString *key = kDefaultTokenizerDelegateKey;
    if (argc > 0) {
        key = [NSString stringWithUTF8String:argv[0]];
    }
    
    tokenizer->delegate = [g_delegateMap objectForKey:key];
    
    if (!tokenizer->delegate) {
        return SQLITE_ERROR;
    }
    
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
    cursor->previousRange = CFRangeMake(0, 0);
    cursor->previousOffsetRange = CFRangeMake(0, 0);
        
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
    
    // The range from the tokenizer is in UTF-16 positions, we need give UTF-8 positions to SQLite
    // Conversion to bytes is very expensive on longer strings. In order to avoid processing the same data over and over again for each token, we cache the previousRange and previousOffsetRange
    // Not all tokenizers may process strings sequentially. Reset the cached ranges if necessary
    if (cursor->currentRange.location < cursor->previousRange.location + cursor->previousRange.length) {
        cursor->previousRange = CFRangeMake(0, 0);
        cursor->previousOffsetRange = CFRangeMake(0, 0);
    }

    // First calculate the offset of current token range in original string
    CFIndex locationOffset, lengthOffset;
    const CFRange rangeToStartToken = CFRangeMake((cursor->previousRange.location + cursor->previousRange.length), cursor->currentRange.location - (cursor->previousRange.location + cursor->previousRange.length));

    // This will tell us how many UTF-8 bytes there are before the start of the token
    CFStringGetBytes(cursor->inputString, rangeToStartToken, kCFStringEncodingUTF8, '?', false,
                     NULL, 0, &locationOffset);
    // and how many UTF-8 bytes there are within the token in the original string
    CFStringGetBytes(cursor->inputString, cursor->currentRange, kCFStringEncodingUTF8, '?', false,
                     NULL, 0, &lengthOffset);

    // Update the location offset
    locationOffset += (cursor->previousOffsetRange.location + cursor->previousOffsetRange.length);

    // Cache the data to reuse on next token
    cursor->previousRange = cursor->currentRange;
    cursor->previousOffsetRange = CFRangeMake(locationOffset, lengthOffset);

    // Determine how many bytes the new token string uses
    CFIndex newBytesUsed;
    const CFRange newTokenRange = CFRangeMake(0, CFStringGetLength(cursor->tokenString));
    CFStringGetBytes(cursor->tokenString, newTokenRange, kCFStringEncodingUTF8, '?', false,
                     cursor->outputBuf, sizeof(cursor->outputBuf), &newBytesUsed);
    
    *pzToken = (char *) cursor->outputBuf;
    *pnBytes = (int) newBytesUsed;
    *piStartOffset = (int) locationOffset;
    *piEndOffset = (int) (locationOffset + lengthOffset);
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

+ (void)registerTokenizer:(id<FMTokenizerDelegate>)tokenizer withKey:(NSString *)key
{
    NSParameterAssert(tokenizer);
    NSParameterAssert([key length]);
    
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        g_delegateMap = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsCopyIn
                                              valueOptions:NSPointerFunctionsWeakMemory];
    });
    
    [g_delegateMap setObject:tokenizer forKey:key];
}

+ (void)registerTokenizer:(id<FMTokenizerDelegate>)tokenizer
{
    [self registerTokenizer:tokenizer withKey:kDefaultTokenizerDelegateKey];
}

- (BOOL)installTokenizerModuleWithName:(NSString *)name
{
    const sqlite3_tokenizer_module *module = &FMDBTokenizerModule;
    NSData *tokenizerData = [NSData dataWithBytes:&module  length:sizeof(module)];
    
    FMResultSet *results = [self executeQuery:@"SELECT fts3_tokenizer(?, ?)", name, tokenizerData];
    
    if ([results next]) {
        [results close];
        return YES;
    }
    
    return NO;
}

- (BOOL)installTokenizerModule
{
    return [self installTokenizerModuleWithName:@"fmdb"];
}

- (BOOL)issueCommand:(NSString *)command forTable:(NSString *)tableName
{
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO %1$@(%1$@) VALUES (?)", tableName];
    
    return [self executeUpdate:sql, command];
}

@end

#pragma mark

@implementation FMTextOffsets
{
    NSString *_rawOffsets;
}

- (instancetype)initWithDBOffsets:(const char *)rawOffsets
{
    if ((self = [super init])) {
        _rawOffsets = [NSString stringWithUTF8String:rawOffsets];
    }
    return self;
}

- (void)enumerateWithBlock:(void (^)(NSInteger, NSInteger, NSRange))block
{
    const char *rawOffsets = [_rawOffsets UTF8String];
    uint32_t offsetInt[4];
    int charsRead = 0;

    while (sscanf(rawOffsets, "%u %u %u %u%n",
                  &offsetInt[0], &offsetInt[1], &offsetInt[2], &offsetInt[3], &charsRead) == 4) {

        block(offsetInt[0], offsetInt[1], NSMakeRange(offsetInt[2], offsetInt[3]));
        rawOffsets += charsRead;
    }
}

@end

@implementation FMResultSet (FTS3)

- (FMTextOffsets *)offsetsForColumnIndex:(int)columnIdx
{
    // The offsets() value is a space separated groups of 4 integers
    const char *rawOffsets = (const char *)sqlite3_column_text([_statement statement], columnIdx);
    
    return [[FMTextOffsets alloc] initWithDBOffsets:rawOffsets];
}

@end
