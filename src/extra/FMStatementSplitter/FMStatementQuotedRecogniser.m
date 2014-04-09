//
//  FMStatementQuotedRecogniser.m
//  FMDB
//
//  Created by openthread on 3/5/14.
//  Copyright (c) 2014 openthread. All rights reserved.
//

#import "FMStatementQuotedRecogniser.h"
#import "FMDatabase.h"

@implementation FMStatementQuotedRecogniser

@synthesize startQuote = _startQuote;
@synthesize endQuote = _endQuote;
@synthesize escapeSequence = _escapeSequence;
@synthesize escapeReplacer = _escapeReplacer;
@synthesize maximumLength = _maximumLength;
@synthesize name = _name;

+ (NSUInteger)minWithLeftParam:(NSUInteger)left rightParam:(NSUInteger)right
{
    return (left < right ? left : right);
}

+ (id)quotedRecogniserWithStartQuote:(NSString *)startQuote endQuote:(NSString *)endQuote name:(NSString *)name
{
    return [FMStatementQuotedRecogniser quotedRecogniserWithStartQuote:startQuote endQuote:endQuote escapeSequence:nil name:name];
}

+ (id)quotedRecogniserWithStartQuote:(NSString *)startQuote endQuote:(NSString *)endQuote escapeSequence:(NSString *)escapeSequence name:(NSString *)name
{
    return [FMStatementQuotedRecogniser quotedRecogniserWithStartQuote:startQuote endQuote:endQuote escapeSequence:escapeSequence maximumLength:NSNotFound name:name];
}

+ (id)quotedRecogniserWithStartQuote:(NSString *)startQuote endQuote:(NSString *)endQuote escapeSequence:(NSString *)escapeSequence maximumLength:(NSUInteger)maximumLength name:(NSString *)name
{
    return FMDBReturnAutoreleased([[FMStatementQuotedRecogniser alloc] initWithStartQuote:startQuote endQuote:endQuote escapeSequence:escapeSequence maximumLength:maximumLength name:name]);
}

- (id)initWithStartQuote:(NSString *)initStartQuote endQuote:(NSString *)initEndQuote escapeSequence:(NSString *)initEscapeSequence maximumLength:(NSUInteger)initMaximumLength name:(NSString *)initName
{
    self = [super init];
    
    if (nil != self)
    {
        [self setStartQuote:initStartQuote];
        [self setEndQuote:initEndQuote];
        [self setEscapeSequence:initEscapeSequence];
        [self setMaximumLength:initMaximumLength];
        [self setName:initName];
    }
    
    return self;
}

#define CPQuotedRecogniserStartQuoteKey     @"Q.s"
#define CPQuotedRecogniserEndQuoteKey       @"Q.e"
#define CPQuotedRecogniserEscapeSequenceKey @"Q.es"
#define CPQuotedRecogniserMaximumLengthKey  @"Q.m"
#define CPQuotedRecogniserNameKey           @"Q.n"

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    
    if (nil != self)
    {
        [self setStartQuote:[aDecoder decodeObjectForKey:CPQuotedRecogniserStartQuoteKey]];
        [self setEndQuote:[aDecoder decodeObjectForKey:CPQuotedRecogniserEndQuoteKey]];
        [self setEscapeSequence:[aDecoder decodeObjectForKey:CPQuotedRecogniserEscapeSequenceKey]];
        @try
        {
            [self setMaximumLength:[aDecoder decodeIntegerForKey:CPQuotedRecogniserMaximumLengthKey]];
        }
        @catch (NSException *exception)
        {
            NSLog(@"Warning, value for maximum length too long for this platform, allowing infinite lengths");
            [self setMaximumLength:NSNotFound];
        }
        [self setName:[aDecoder decodeObjectForKey:CPQuotedRecogniserNameKey]];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    if (nil != [self escapeReplacer])
    {
        NSLog(@"Warning: encoding CPQuoteRecogniser with an escapeReplacer set.  This will not be recreated when decoded.");
    }
    [aCoder encodeObject:[self startQuote]     forKey:CPQuotedRecogniserStartQuoteKey];
    [aCoder encodeObject:[self endQuote]       forKey:CPQuotedRecogniserEndQuoteKey];
    [aCoder encodeObject:[self escapeSequence] forKey:CPQuotedRecogniserEscapeSequenceKey];
    [aCoder encodeInteger:[self maximumLength] forKey:CPQuotedRecogniserMaximumLengthKey];
    [aCoder encodeObject:[self name]           forKey:CPQuotedRecogniserNameKey];
}

- (NSRange)recogniseRangeWithScanner:(NSScanner *)scanner currentTokenPosition:(NSUInteger *)tokenPosition
{
    NSString *(^er)(NSString *tokenStream, NSUInteger *quotePosition) = [self escapeReplacer];
    NSUInteger startQuoteLength = [self.startQuote length];
    NSUInteger endQuoteLength = [self.endQuote length];
    NSString *tokenString = [scanner string];

    long inputLength = [tokenString length];
    NSUInteger rangeLength = [FMStatementQuotedRecogniser minWithLeftParam:inputLength - *tokenPosition
                                                                rightParam:startQuoteLength + endQuoteLength + self.maximumLength];
    CFRange searchRange = CFRangeMake(*tokenPosition, rangeLength);
    CFRange range;
    BOOL matched = CFStringFindWithOptions((CFStringRef)tokenString, (CFStringRef)self.startQuote, searchRange, kCFCompareAnchored, &range);
    
    CFMutableStringRef outputString = CFStringCreateMutable(kCFAllocatorDefault, 0);
    
    if (matched)
    {
        searchRange.location = searchRange.location + range.length;
        searchRange.length   = searchRange.length   - range.length;
        
        CFRange endRange;
        CFRange escapeRange;
        BOOL matchedEndSequence = CFStringFindWithOptions((CFStringRef)tokenString, (CFStringRef)self.endQuote, searchRange, 0L, &endRange);
        BOOL matchedEscapeSequence = nil == self.escapeSequence ? NO : CFStringFindWithOptions((CFStringRef)tokenString, (CFStringRef)self.escapeSequence, searchRange, 0L, &escapeRange);
        
        while (matchedEndSequence && searchRange.location < inputLength)
        {
            if (!matchedEscapeSequence || endRange.location < escapeRange.location)//End quote is not escaped by escape sequence.
            {
                NSUInteger resultRangeBegin = *tokenPosition;
                *tokenPosition = endRange.location + endRange.length;
                NSUInteger resultRangeLength = *tokenPosition - resultRangeBegin;
                CFRelease(outputString);
                return NSMakeRange(resultRangeBegin, resultRangeLength);
            }
            else//End quote is escaped by escape sequence
            {
                NSUInteger quotedPosition = escapeRange.location + escapeRange.length;
                CFRange subStrRange = CFRangeMake(searchRange.location,
                                                  escapeRange.location + (self.shouldQuoteEscapeSequence ? escapeRange.length : 0) - searchRange.location);
                CFStringRef substr = CFStringCreateWithSubstring(kCFAllocatorDefault, (CFStringRef)tokenString, subStrRange);
                CFStringAppend(outputString, substr);
                CFRelease(substr);
                BOOL appended = NO;
                if (nil != er)
                {
                    NSString *s = er(tokenString, &quotedPosition);
                    if (nil != s)
                    {
                        appended = YES;
                        CFStringAppend(outputString, (CFStringRef)s);
                    }
                }
                if (!appended)
                {
                    substr = CFStringCreateWithSubstring(kCFAllocatorDefault, (CFStringRef)tokenString, CFRangeMake(escapeRange.location + escapeRange.length, 1));
                    CFStringAppend(outputString, substr);
                    CFRelease(substr);
                    quotedPosition += 1;
                }
                searchRange.length   = searchRange.location + searchRange.length - quotedPosition;
                searchRange.location = quotedPosition;
                
                if (endRange.location < searchRange.location)
                {
                    matchedEndSequence = CFStringFindWithOptions((CFStringRef)tokenString, (CFStringRef)self.endQuote, searchRange, 0L, &endRange);
                }
                if (escapeRange.location < searchRange.location)
                {
                    matchedEscapeSequence = CFStringFindWithOptions((CFStringRef)tokenString, (CFStringRef)self.escapeSequence, searchRange, 0L, &escapeRange);
                }
            }
        }
    }
    
    CFRelease(outputString);
    return NSMakeRange(NSNotFound, 0);
}

@end
