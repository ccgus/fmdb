//
//  FMStatementTokenRecogniser.h
//  FMDB
//
//  Created by openthread on 3/5/14.
//  Copyright (c) 2014 openthread. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * The FMStatementTokenRecogniser protocol.
 */
@protocol FMStatementTokenRecogniser <NSObject>

@required
/**
 * Recognise token with a scanner.
 * @param scanner The recognising scanner.
 * @param tokenPosition Begining token position to recognise of scanner.
 *
 * @return Returns the recognised token range of scanner. If not recognised, the location of return value is `NSNotFound`.
 */
- (NSRange)recogniseRangeWithScanner:(NSScanner *)scanner currentTokenPosition:(NSUInteger *)tokenPosition;

@end
