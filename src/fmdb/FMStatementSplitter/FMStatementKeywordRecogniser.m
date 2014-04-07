//
//  FMStatementKeywordRecogniser.m
//  FMDB
//
//  Created by openthread on 3/5/14.
//  Copyright (c) 2014 openthread. All rights reserved.
//

#import "FMStatementKeywordRecogniser.h"
#import "FMDatabase.h"

@implementation FMStatementKeywordRecogniser

@synthesize keywords = _keywords;
@synthesize invalidFollowingCharacters = _invalidFollowingCharacters;

+ (id)recogniserForKeyword:(NSString *)keyword
{
    return [self recogniserForKeywords:@[keyword]];
}

+ (id)recogniserForKeywords:(NSArray *)keywords
{
    return FMDBReturnAutoreleased([[self alloc] initWithKeywords:keywords]);
}

- (id)initWithKeyword:(NSString *)keyword
{
    return [self initWithKeywords:@[keyword]];
}

- (id)initWithKeywords:(NSArray *)keywords
{
    return [self initWithKeywords:keywords invalidFollowingCharacters:nil];
}

+ (id)recogniserForKeyword:(NSString *)keyword invalidFollowingCharacters:(NSCharacterSet *)invalidFollowingCharacters
{
    return [self recogniserForKeywords:@[keyword]
            invalidFollowingCharacters:invalidFollowingCharacters];
}

+ (id)recogniserForKeywords:(NSArray *)keywords invalidFollowingCharacters:(NSCharacterSet *)invalidFollowingCharacters
{
    return FMDBReturnAutoreleased([[self alloc] initWithKeywords:keywords invalidFollowingCharacters:invalidFollowingCharacters]);
}

- (id)initWithKeyword:(NSString *)keyword invalidFollowingCharacters:(NSCharacterSet *)invalidFollowingCharacters
{
    return [self initWithKeywords:@[keyword] invalidFollowingCharacters:invalidFollowingCharacters];
}

- (id)initWithKeywords:(NSArray *)keywords invalidFollowingCharacters:(NSCharacterSet *)invalidFollowingCharacters
{
    self = [super init];
    
    if (nil != self)
    {
        self.keywords = keywords;
        [self setInvalidFollowingCharacters:invalidFollowingCharacters];
    }
    
    return self;
}

- (id)init
{
    return [self initWithKeyword:@" "];
}

#define CPKeywordRecogniserKeywordKey @"K.k"
#define CPKeywordRecogniserInvalidFollowingCharactersKey @"K.f"

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    
    if (nil != self)
    {
        [self setKeywords:[aDecoder decodeObjectForKey:CPKeywordRecogniserKeywordKey]];
        [self setInvalidFollowingCharacters:[aDecoder decodeObjectForKey:CPKeywordRecogniserInvalidFollowingCharactersKey]];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:[self keywords] forKey:CPKeywordRecogniserKeywordKey];
    [aCoder encodeObject:[self invalidFollowingCharacters] forKey:CPKeywordRecogniserInvalidFollowingCharactersKey];
}

- (NSRange)recogniseRangeWithScanner:(NSScanner *)scanner currentTokenPosition:(NSUInteger *)tokenPosition
{
    for (NSString *keyword in self.keywords)
    {
        NSUInteger kwLength = [keyword length];
        NSUInteger remainingChars = [[scanner string] length] - *tokenPosition;
        if (remainingChars >= kwLength)
        {
            if (CFStringFindWithOptions((CFStringRef)[scanner string], (CFStringRef)keyword, CFRangeMake(*tokenPosition, kwLength), kCFCompareAnchored | kCFCompareCaseInsensitive, NULL))
            {
                if (remainingChars == kwLength ||
                    nil == self.invalidFollowingCharacters ||
                    !CFStringFindCharacterFromSet((CFStringRef)[scanner string], (CFCharacterSetRef)self.invalidFollowingCharacters, CFRangeMake(*tokenPosition + kwLength, 1), kCFCompareAnchored, NULL))
                {
                    NSRange result = NSMakeRange(*tokenPosition, kwLength);
                    *tokenPosition = *tokenPosition + kwLength;
                    return result;
                }
            }
        }
    }
    
    return NSMakeRange(NSNotFound, 0);
}

@end
