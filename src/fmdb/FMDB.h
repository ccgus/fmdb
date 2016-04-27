#import <Foundation/Foundation.h>

FOUNDATION_EXPORT double FMDBVersionNumber;
FOUNDATION_EXPORT const unsigned char FMDBVersionString[];

#import "FMDatabase.h"
#import "FMResultSet.h"
#import "FMDatabaseAdditions.h"
#import "FMDatabaseQueue.h"
#import "FMDatabasePool.h"

@interface AXUDataBaseHandle : NSObject

@property(nonatomic, strong)FMDatabaseQueue *queue;

+ (instancetype)shareInstance;

- (void)execSqlInFmdb:(void (^)())block;
- (void)creatTable:(NSString *)tableName withSql:(NSString *)sql;
- (void)insertDataIntoDataBase:(NSString *)tableName withSql:(NSString *)sql;
- (void)deleteDataFromDataBase:(NSString *)tableName withSql:(NSString *)sql;
- (void)updateDataFromDataBase:(NSString *)tableName withSql:(NSString *)sql;

@end