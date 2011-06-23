//
//  FMDatabasePool.h
//  fmdb
//
//  Created by August Mueller on 6/22/11.
//  Copyright 2011 Flying Meat Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class FMDatabase;

@interface FMDatabasePool : NSObject {
    NSString            *_path;
    
    dispatch_queue_t    _lockQueue;
    
    NSMutableArray      *_databaseInPool;
    NSMutableArray      *_databaseOutPool;
    
    id                  _delegate;
    
    NSUInteger          _maximumNumberOfDatabasesToCreate;
}

@property (retain) NSString *path;
@property (assign) id delegate;
@property (assign) NSUInteger maximumNumberOfDatabasesToCreate;

+ (id)databasePoolWithPath:(NSString*)aPath;
- (id)initWithPath:(NSString*)aPath;

- (void)pushDatabaseBackInPool:(FMDatabase*)db;
- (FMDatabase*)db;

- (NSUInteger)countOfOpenDatabases;
- (void)releaseAllDatabases;

- (void)useDatabase:(void (^)(FMDatabase *db))block;

- (void)useTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block;

@end


@interface NSObject (FMDatabasePoolDelegate)

- (BOOL)databasePool:(FMDatabasePool*)pool shouldAddDatabaseToPool:(FMDatabase*)database;

@end

