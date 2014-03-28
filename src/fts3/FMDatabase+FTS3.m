//
//  FMDatabase+FTS3.m
//  fmdb
//
//  Created by Andrew on 3/27/14.
//  Copyright (c) 2014 Andrew Goodale. All rights reserved.
//

#import "FMDatabase+FTS3.h"
#import "fts3_tokenizer.h"

/* I know this is an evil global, but I'm not sure an app needs multiple tokenizers anyway...*/
static id<FMTokenizerDelegate> __unsafe_unretained g_delegate = nil;

/*
 ** Class derived from sqlite3_tokenizer
 */
struct FMDBTokenizer
{
    sqlite3_tokenizer base;
};

/*
 ** Create a new tokenizer instance.
 */
static int FMDBTokenizerCreate(int argc, const char * const *argv, sqlite3_tokenizer **ppTokenizer)
{
    struct FMDBTokenizer *t;
    
    t = (struct FMDBTokenizer *) sqlite3_malloc(sizeof(*t));
    
    if ( t==NULL ) {
        return SQLITE_NOMEM;
    }
    
    memset(t, 0, sizeof(*t));
    *ppTokenizer = &t->base;
    
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
    FMTokenizerCursor *cursor = (FMTokenizerCursor *)sqlite3_malloc(sizeof(FMTokenizerCursor));
    
    if (cursor == NULL) {
        return SQLITE_NOMEM;
    }
    
    nBytes = (nBytes < 0) ? (int) strlen(pInput) : nBytes;
    cursor->inputString = CFStringCreateWithBytesNoCopy(NULL, (const UInt8 *)pInput, nBytes,
                                                        kCFStringEncodingUTF8, false, kCFAllocatorNull);
    cursor->currentRange = CFRangeMake(0, 0);
    cursor->tokenIndex = 0;
    cursor->tokenString = NULL;
    cursor->userObject = NULL;
    cursor->tempBuffer = NULL;
        
    [g_delegate openTokenizerCursor:cursor];

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
    
    [g_delegate closeTokenizerCursor:cursor];
    
    if (cursor->userObject) {
        CFRelease(cursor->userObject);
    }
    if (cursor->tokenString) {
        CFRelease(cursor->tokenString);
    }
    
    CFRelease(cursor->inputString);
    sqlite3_free(cursor->tempBuffer);
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
    
    if ([g_delegate nextTokenForCursor:cursor]) {
        return SQLITE_DONE;
    }
    
    const char *strToken = CFStringGetCStringPtr(cursor->tokenString, kCFStringEncodingUTF8);
    
    if (strToken == NULL) {
        // Need to allocate some of our own memory for this.
        if (cursor->tempBuffer == NULL) {
            cursor->tempBuffer = sqlite3_malloc(128);   //TODO: fix hard-coded constant
        }

        CFStringGetCString(cursor->tokenString, cursor->tempBuffer, 128, kCFStringEncodingUTF8);
        strToken = cursor->tempBuffer;
    }
    
    *pzToken = strToken;
    *pnBytes = (int) strlen(strToken);
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

- (BOOL)registerTokenizer:(id<FMTokenizerDelegate>)tokenizer withName:(NSString *)name
{
    NSParameterAssert(tokenizer);

    if (g_delegate == tokenizer) {
        return YES;
    }
    
    const sqlite3_tokenizer_module *module = &FMDBTokenizerModule;
    NSData *tokenizerData = [NSData dataWithBytes:&module  length:sizeof(module)];
    
    FMResultSet *results = [self executeQuery:@"SELECT fts3_tokenizer(?, ?)", name, tokenizerData];
    
    if ([results next]) {
        [results close];
        g_delegate = tokenizer;
        
        return YES;
    }
    
    return NO;
}

@end
