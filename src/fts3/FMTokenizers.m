//
//  FMTokenizers.m
//  fmdb
//
//  Created by Andrew on 4/9/14.
//  Copyright (c) 2014 Andrew Goodale. All rights reserved.
//

#import "FMTokenizers.h"

@implementation FMSimpleTokenizer
{
    CFLocaleRef m_locale;
}

- (id)initWithLocale:(CFLocaleRef)locale
{
    if ((self = [super init])) {
        m_locale = (locale != NULL) ? CFRetain(locale) : CFLocaleCopyCurrent();
    }
    return self;
}

- (void)dealloc
{
    CFRelease(m_locale);
}

- (void)openTokenizerCursor:(FMTokenizerCursor *)cursor
{
    cursor->tokenString = CFStringCreateMutable(NULL, 0);
    cursor->userObject = CFStringTokenizerCreate(NULL, cursor->inputString,
                                                 CFRangeMake(0, CFStringGetLength(cursor->inputString)),
                                                 kCFStringTokenizerUnitWord, m_locale);
}

- (BOOL)nextTokenForCursor:(FMTokenizerCursor *)cursor
{
    CFStringTokenizerRef tokenizer = (CFStringTokenizerRef) cursor->userObject;
    CFMutableStringRef tokenString = (CFMutableStringRef) cursor->tokenString;
    
    CFStringTokenizerTokenType tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer);
    
    if (tokenType == kCFStringTokenizerTokenNone) {
        // No more tokens, we are finished.
        return YES;
    }
        
    // Found a regular word. The token is the lowercase version of the word.
    cursor->currentRange = CFStringTokenizerGetCurrentTokenRange(tokenizer);

    // The inline buffer approach is faster and uses less memory than CFStringCreateWithSubstring()
    CFStringInlineBuffer inlineBuf;
    CFStringInitInlineBuffer(cursor->inputString, &inlineBuf, cursor->currentRange);
    CFStringDelete(tokenString, CFRangeMake(0, CFStringGetLength(tokenString)));
    
    for (int i = 0; i < cursor->currentRange.length; ++i) {
        UniChar nextChar = CFStringGetCharacterFromInlineBuffer(&inlineBuf, i);
        CFStringAppendCharacters(tokenString, &nextChar, 1);
    }
    
    CFStringLowercase(tokenString, m_locale);
    
    return NO;
}

- (void)closeTokenizerCursor:(FMTokenizerCursor *)cursor
{
    // FMDatabase will CFRelease the tokenString and the userObject.
}

@end

#pragma mark

@implementation FMStopWordTokenizer
{
    id<FMTokenizerDelegate> m_baseTokenizer;
}

@synthesize words = m_words;

+ (instancetype)tokenizerWithFileURL:(NSURL *)wordFileURL
                       baseTokenizer:(id<FMTokenizerDelegate>)tokenizer
                               error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(wordFileURL);
    
    NSString *contents = [NSString stringWithContentsOfURL:wordFileURL encoding:NSUTF8StringEncoding error:error];
    NSArray *stopWords = [contents componentsSeparatedByString:@"\n"];

    if (contents == nil) {
        return nil;
    }
    return [[self alloc] initWithWords:[NSSet setWithArray:stopWords] baseTokenizer:tokenizer];
}

- (instancetype)initWithWords:(NSSet *)words baseTokenizer:(id<FMTokenizerDelegate>)tokenizer
{
    NSParameterAssert(tokenizer);
    
    if ((self = [super init])) {
        m_words = [words copy];
        m_baseTokenizer = tokenizer;
    }
    return self;
}

- (void)openTokenizerCursor:(FMTokenizerCursor *)cursor
{
    [m_baseTokenizer openTokenizerCursor:cursor];
}

- (BOOL)nextTokenForCursor:(FMTokenizerCursor *)cursor
{
    BOOL done = [m_baseTokenizer nextTokenForCursor:cursor];
    
    // Don't use stop words for prefix queries since it's fine for the prefix to be in the stop list
    if (CFStringHasSuffix(cursor->inputString, CFSTR("*"))) {
        return done;
    }
    
    while (!done && [self.words containsObject:(__bridge id)(cursor->tokenString)]) {
        done = [m_baseTokenizer nextTokenForCursor:cursor];
    }
    
    return done;
}

- (void)closeTokenizerCursor:(FMTokenizerCursor *)cursor
{
    [m_baseTokenizer closeTokenizerCursor:cursor];
}

@end