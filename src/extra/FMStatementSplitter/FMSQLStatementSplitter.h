//
//  FMSQLStatementSplitter.h
//  FMDB
//
//  Created by openthread on 3/5/14.
//  Copyright (c) 2014 openthread. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * The FMSplittedStatement class contains a separated statement.
 */
@interface FMSplittedStatement : NSObject

/**
 * Separated statement string.
 */
@property (nonatomic, retain) NSString *statementString;//statement string
@end

@interface FMSQLStatementSplitter : NSObject

/**
 * Get singleton instance.
 */
+ (instancetype)sharedInstance;

/**
 * Split batch sql statement into separated statements.
 *
 * @param batchStatement The batch statement string to split.
 *
 * @return Returns the array of splitted statements. Each member of return value is an `FMSplittedStatement`.
 *
 * @see FMSplittedStatement
 */
- (NSArray *)statementsFromBatchSqlStatement:(NSString *)batchStatement;

@end
