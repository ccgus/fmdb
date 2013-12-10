//
//  FMDBTempDBTests.h
//  fmdb
//
//  Created by Graham Dennis on 24/11/2013.
//
//

#import <XCTest/XCTest.h>
#import "FMDatabase.h"

@protocol FMDBTempDBTests <NSObject>

@optional
+ (void)populateDatabase:(FMDatabase *)database;

@end

@interface FMDBTempDBTests : XCTestCase <FMDBTempDBTests>

@property FMDatabase *db;
@property (readonly) NSString *databasePath;

@end
