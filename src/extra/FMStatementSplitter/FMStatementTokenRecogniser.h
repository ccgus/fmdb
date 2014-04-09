//
//  FMStatementTokenRecogniser.h
//  FMDB
//
//  Created by openthread on 3/5/14.
//  Copyright (c) 2014 openthread. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FMStatementTokenRecogniser <NSObject, NSCoding>

@required
- (NSRange)recogniseRangeWithScanner:(NSScanner *)scanner currentTokenPosition:(NSUInteger *)tokenPosition;

@end
