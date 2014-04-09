//
//  FMSQLStatementSplitter.h
//  FMDB
//
//  Created by openthread on 3/5/14.
//  Copyright (c) 2014 openthread. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FMSplittedStatement : NSObject
@property (nonatomic, retain) NSString *statementString;//statement string
@end

@interface FMSQLStatementSplitter : NSObject

+ (instancetype)sharedInstance;

- (NSArray *)statementsFromBatchSqlStatement:(NSString *)batchStatement;

@end
