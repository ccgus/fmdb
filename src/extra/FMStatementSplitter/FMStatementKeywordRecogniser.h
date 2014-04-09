//
//  FMStatementKeywordRecogniser.h
//  FMDB
//
//  Created by openthread on 3/5/14.
//  Copyright (c) 2014 openthread. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FMStatementTokenRecogniser.h"

/**
 * The FMStatementKeywordRecogniser class attempts to recognise a specific keyword in a token stream.
 * 
 * A keyword recogniser attempts to recognise a specific word or set of symbols.
 * Keyword recognisers can also check that the keyword is not followed by specific characters in order to stop it recognising the beginnings of words.
 */
@interface FMStatementKeywordRecogniser : NSObject <FMStatementTokenRecogniser>

///---------------------------------------------------------------------------------------
/// @name Creating and Initialising a Keyword Recogniser
///---------------------------------------------------------------------------------------

/**
 * Creates a Keyword Recogniser for a specific keyword.
 * 
 * @param keyword The keyword to recognise.
 *
 * @return Returns a keyword recogniser for the passed keyword.
 *
 * @see initWithKeyword:
 * @see recogniserForKeyword:invalidFollowingCharacters:
 */
+ (id)recogniserForKeyword:(NSString *)keyword;

+ (id)recogniserForKeywords:(NSArray *)keywords;

/**
 * Creates a Keyword Recogniser for a specific keyword.
 * 
 * @param keyword The keyword to recognise.
 * @param invalidFollowingCharacters A set of characters that may not follow the keyword in the string being tokenised.
 *
 * @return Returns a keyword recogniser for the passed keyword.
 *
 * @see recogniserForKeyword:
 * @see initWithKeyword:invalidFollowingCharacters:
 */
+ (id)recogniserForKeyword:(NSString *)keyword invalidFollowingCharacters:(NSCharacterSet *)invalidFollowingCharacters;

+ (id)recogniserForKeywords:(NSArray *)keywords invalidFollowingCharacters:(NSCharacterSet *)invalidFollowingCharacters;

/**
 * Initialises a Keyword Recogniser to recognise a specific keyword.
 * 
 * @param keyword The keyword to recognise.
 *
 * @return Returns the keyword recogniser initialised to recognise the passed keyword.
 *
 * @see recogniserForKeyword:
 * @see initWithKeyword:invalidFollowingCharacters:
 */
- (id)initWithKeyword:(NSString *)keyword;

- (id)initWithKeywords:(NSArray *)keywords;

/**
 * Initialises a Keyword Recogniser to recognise a specific keyword.
 * 
 * @param keyword The keyword to recognise.
 * @param invalidFollowingCharacters A set of characters that may not follow the keyword in the string being tokenised.
 *
 * @return Returns the keyword recogniser initialised to recognise the passed keyword.
 *
 * @see initWithKeyword:
 * @see recogniserForKeyword:invalidFollowingCharacters:
 */
- (id)initWithKeyword:(NSString *)keyword invalidFollowingCharacters:(NSCharacterSet *)invalidFollowingCharacters;

- (id)initWithKeywords:(NSArray *)keywords invalidFollowingCharacters:(NSCharacterSet *)invalidFollowingCharacters;

///---------------------------------------------------------------------------------------
/// @name Configuring a Keyword Recogniser
///---------------------------------------------------------------------------------------

/**
 * The keyword that the recogniser should attempt to recognise.
 */
@property (readwrite,retain,nonatomic) NSArray *keywords;

/**
 * A set of characters that may not follow the keyword.
 */
@property (readwrite,retain,nonatomic) NSCharacterSet *invalidFollowingCharacters;

@end
