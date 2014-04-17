//
//  FMTokenizers.h
//  fmdb
//
//  Created by Andrew on 4/9/14.
//  Copyright (c) 2014 Andrew Goodale. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDatabase+FTS3.h"

/**
 This is the base tokenizer implementation, using a CFStringTokenizer to find words.
 */
@interface FMSimpleTokenizer : NSObject <FMTokenizerDelegate>

/**
 Create the tokenizer with a given locale. The locale will be used to initialize the string tokenizer and to lowercase the parsed word.
 The locale can be `NULL`, in which case the current locale will be used.
 */
- (instancetype)initWithLocale:(CFLocaleRef)locale;

@end

#pragma mark

/**
 This tokenizer extends the simple tokenizer with support for a stop word list.
 */
@interface FMStopWordTokenizer : NSObject <FMTokenizerDelegate>

@property (atomic, copy) NSSet *words;

/**
 Load a stop-word tokenizer using a file containing words delimited by newlines. The file should be encoded in UTF-8.
 */
+ (instancetype)tokenizerWithFileURL:(NSURL *)wordFileURL baseTokenizer:(id<FMTokenizerDelegate>)tokenizer error:(NSError **)error;

/**
 Initialize an instance of the tokenizer using the set of words. The words should be lowercase if you're using the 
 `FMSimpleTokenizer` as the base.
 */
- (instancetype)initWithWords:(NSSet *)words baseTokenizer:(id<FMTokenizerDelegate>)tokenizer;

@end
