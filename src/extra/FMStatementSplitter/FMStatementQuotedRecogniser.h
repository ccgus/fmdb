//
//  FMStatementQuotedRecogniser.h
//  FMDB
//
//  Created by openthread on 3/5/14.
//  Copyright (c) 2014 openthread. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FMStatementTokenRecogniser.h"

/**
 * The FMStatementQuotedRecogniser class is used to recognise quoted literals in the input string.  This can be used for quoted strings, characters, comments and many other things.
 * 
 * Quoted tokens are recognised via a start string and end string.  You may optionally add an escape sequence string that stops the end quote being recognised at that point in the input.
 * You may optionally provide a block used to replace escape sequences with their actual meaning.  If you don't provide an escape replcement block it is assumed that the character
 * following the escape sequence replaces the whole sequence.
 *
 * Finally, you may also provide a maximum length for the quoted sequence to recognise.  If you want to recognise strings of any length, pass NSNotFound.
 */
@interface FMStatementQuotedRecogniser : NSObject <FMStatementTokenRecogniser>

///---------------------------------------------------------------------------------------
/// @name Creating and Initialising a Quoted Recogniser
///---------------------------------------------------------------------------------------

/**
 * Creates a quoted recogniser that recognises quoted litterals starting with startQuote and ending with endQuote.
 *
 * @param startQuote A string that indicates the beginning of a quoted literal.
 * @param endQuote   A string that indicates the end of the quoted literal.
 * @param name       The name to attach to recognised tokens.
 * @return Returns a FMStatementQuotedRecogniser that recognises C like identifiers.
 *
 * @see quotedRecogniserWithStartQuote:endQuote:escapeSequence:name:
 * @see quotedRecogniserWithStartQuote:endQuote:escapeSequence:maximumLength:name:
 */
+ (id)quotedRecogniserWithStartQuote:(NSString *)startQuote endQuote:(NSString *)endQuote name:(NSString *)name;

/**
 * Creates a quoted recogniser that recognises quoted litterals starting with startQuote and ending with endQuote.  Escaped sequences are recognised by the escapeSequence string.
 *
 * @param startQuote     A string that indicates the beginning of a quoted literal.
 * @param endQuote       A string that indicates the end of the quoted literal.
 * @param escapeSequence A string that indicates an escaped character.
 * @param name           The name to attach to recognised tokens.
 * @return Returns a FMStatementQuotedRecogniser that recognises C like identifiers.
 *
 * @see quotedRecogniserWithStartQuote:endQuote:name:
 * @see quotedRecogniserWithStartQuote:endQuote:escapeSequence:maximumLength:name:
 */
+ (id)quotedRecogniserWithStartQuote:(NSString *)startQuote endQuote:(NSString *)endQuote escapeSequence:(NSString *)escapeSequence name:(NSString *)name;

/**
 * Creates a quoted recogniser that recognises quoted litterals starting with startQuote and ending with endQuote.  Escaped sequences are recognised by the escapeSequence string.  Quoted strings have a maximum length.
 *
 * @param startQuote     A string that indicates the beginning of a quoted literal.
 * @param endQuote       A string that indicates the end of the quoted literal.
 * @param escapeSequence A string that indicates an escaped character.
 * @param maximumLength  The maximum length of the resulting string.
 * @param name           The name to attach to recognised tokens.
 * @return Returns a FMStatementQuotedRecogniser that recognises C like identifiers.
 *
 * @see quotedRecogniserWithStartQuote:endQuote:name:
 * @see quotedRecogniserWithStartQuote:endQuote:escapeSequence:name:
 * @see initWithStartQuote:endQuote:escapeSequence:maximumLength:name:
 */
+ (id)quotedRecogniserWithStartQuote:(NSString *)startQuote endQuote:(NSString *)endQuote escapeSequence:(NSString *)escapeSequence maximumLength:(NSUInteger)maximumLength name:(NSString *)name;

/**
 * Initialises a quoted recogniser that recognises quoted litterals starting with startQuote and ending with endQuote.  Escaped sequences are recognised by the escapeSequence string.  Quoted strings have a maximum length.
 *
 * @param startQuote     A string that indicates the beginning of a quoted literal.
 * @param endQuote       A string that indicates the end of the quoted literal.
 * @param escapeSequence A string that indicates an escaped character.
 * @param maximumLength  The maximum length of the resulting string.
 * @param name           The name to attach to recognised tokens.
 * @return Returns a FMStatementQuotedRecogniser that recognises C like identifiers.
 *
 * @see quotedRecogniserWithStartQuote:endQuote:escapeSequence:maximumLength:name:
 */
- (id)initWithStartQuote:(NSString *)startQuote endQuote:(NSString *)endQuote escapeSequence:(NSString *)escapeSequence maximumLength:(NSUInteger)maximumLength name:(NSString *)name;

///---------------------------------------------------------------------------------------
/// @name Configuring a Quoted Recogniser
///---------------------------------------------------------------------------------------

/**
 * Determines the string used to indicate the start of the quoted literal.
 *
 * @see endQuote
 */
@property (readwrite,copy) NSString *startQuote;

/**
 * Determines the string used to indicate the end of the quoted literal.
 *
 * @see startQuote
 */
@property (readwrite,copy) NSString *endQuote;

/**
 * Determines the string used to indicate an escaped character in the quoted literal.
 */
@property (readwrite,copy) NSString *escapeSequence;

/**
 * If `YES`, quoted string will contains `escapeSequence`.
 * If `NO`, quoted string will not contains `escapeSequence`.
 * Default is `NO`.
 */
@property (nonatomic, assign) BOOL shouldQuoteEscapeSequence;

/**
 * Determines how much of the input string to consume when an escaped literal is found, and what to replace it with.
 */
@property (readwrite,copy) NSString *(^escapeReplacer)(NSString *tokenStream, NSUInteger *quotePosition);

/**
 * Determines the maximum length of the quoted literal not including quotes.  To indicate the literal can be any length specify NSNotFound.
 */
@property (readwrite,assign) NSUInteger maximumLength;

/**
 * Determines the name of the token produced.
 */
@property (readwrite,copy) NSString *name;

@end
