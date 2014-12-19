//
//  FMReadOnlyDatabasePool.m
//  LayerKit
//
//  Created by Blake Watters on 12/18/14.
//  Copyright (c) 2014 Layer Inc. All rights reserved.
//

#import "FMReadOnlyDatabasePool.h"

@interface LYRDatabaseProxy : NSObject {
    FMDatabase *_database;
    dispatch_semaphore_t _semaphore;
}

- (id)initWithDatabase:(FMDatabase *)database semaphore:(dispatch_semaphore_t)semaphore;
- (void)__waitForSemaphore;

@end

@implementation LYRDatabaseProxy

- (id)initWithDatabase:(FMDatabase *)database semaphore:(dispatch_semaphore_t)semaphore
{
    // NSProxy objects don't respond to `init`
    self = [super init];
    if (self) {
        _database = database;
        _semaphore = semaphore;
    }
    return self;
}

- (void)__waitForSemaphore
{
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
}

- (void)__signalSemaphore
{
    if (_semaphore) {
        dispatch_semaphore_signal(_semaphore);
        _semaphore = NULL;
    }
}

- (FMDatabase *)__proxiedDatabase
{
    return _database;
}

- (void)dealloc
{
    if (_database && _semaphore) {
        // If we still have a reference to the semaphore then we are deallocating without being cleaned up. Close the open result sets before signaling and returning to the pool
        [_database closeOpenResultSets];
    }
    [self __signalSemaphore];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if ([_database respondsToSelector:aSelector]) {
        return _database;
    }
    
    return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    if ([super respondsToSelector:aSelector]) {
        return YES;
    } else {
        if ([_database respondsToSelector:aSelector]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isKindOfClass:(Class)aClass
{
    if ([super isKindOfClass:aClass]) {
        return YES;
    } else {
        if ([_database isKindOfClass:aClass]) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p database=%@:%p>", [self class], self, [_database class], _database];
}

@end

@interface FMReadOnlyDatabasePool ()

@property (nonatomic) NSSet *pool;
@property (nonatomic) dispatch_queue_t collectionGuardSerialQueue;
@property (nonatomic) dispatch_semaphore_t poolSemaphore;
@property (nonatomic) NSHashTable *busyDatabases;

@end

@implementation FMReadOnlyDatabasePool

+ (instancetype)databasePoolWithPath:(NSString *)path flags:(int)flags capacity:(NSUInteger)numberOfDatabases
{
    return [[FMReadOnlyDatabasePool alloc] initWithPath:path flags:flags numberOfDatabases:numberOfDatabases];
}

- (id)initWithPath:(NSString *)path flags:(int)flags numberOfDatabases:(NSUInteger)numberOfDatabases
{
    // TODO: Verify that flags contains SQLITE_OPEN_READONLY
    if (!(flags & SQLITE_OPEN_READONLY)) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Expected flags to include `SQLITE_OPEN_READONLY`" userInfo:nil];
    }
    self = [super init];
    if (self) {
        if (path == nil) [NSException raise:NSInternalInconsistencyException format:@"Cannot initialize a database pool manager without the `path` parameter."];
        if (numberOfDatabases == 0) [NSException raise:NSInternalInconsistencyException format:@"Cannot initialize a database pool manager with `numberOfDatabases` set to zero."];

        NSMutableSet *pool = [NSMutableSet setWithCapacity:numberOfDatabases];
        
        for (int i=0; i<numberOfDatabases; i++) {
            FMDatabase *database = [FMDatabase databaseWithPath:path];
            BOOL success = [database openWithFlags:flags];
            
            // If db failed to open the database at given resource path, fail instantiation
            if (!success) {
                LYRLogError(@"could not instantiate and open SQLite db connection with path: %@", path);
                return nil;
            }
            
            database.maxBusyRetryTimeInterval = 5.0;
            
            // Add the database to the pool
            [pool addObject:database];
        }
        
        _pool = pool;
        _collectionGuardSerialQueue = dispatch_queue_create("com.layer.FMReadOnlyDatabasePoolQueue", DISPATCH_QUEUE_SERIAL);
        
        _busyDatabases = [NSHashTable weakObjectsHashTable];
        _poolSemaphore = dispatch_semaphore_create(numberOfDatabases);
    }
    return self;
}

- (void)dealloc
{
    for (FMDatabase *database in self.pool) {
        [database close];
    }
}

- (instancetype)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Failed to call designated initializer. Call `%@` instead.", NSStringFromSelector(@selector(databasePoolWithPath:flags:capacity:))] userInfo:nil];
}

- (NSSet *)availableDatabases
{
    NSSet *busyDatabases = [[self.busyDatabases setRepresentation] valueForKey:@"__proxiedDatabase"];
    NSMutableSet *availableDatabases = [self.pool mutableCopy];
    [availableDatabases minusSet:busyDatabases];
    return availableDatabases;
}

- (FMDatabase *)availableDatabase
{
    __block LYRDatabaseProxy *databaseProxy = nil;
    dispatch_sync(self.collectionGuardSerialQueue, ^{
        FMDatabase *availableDatabase = [[self availableDatabases] anyObject];
        if (availableDatabase) {
            databaseProxy = [[LYRDatabaseProxy alloc] initWithDatabase:availableDatabase semaphore:self.poolSemaphore];
            [databaseProxy __waitForSemaphore];
            [self.busyDatabases addObject:databaseProxy];
        }
    });
    return (FMDatabase *)databaseProxy;
}

- (FMDatabase *)waitForAvailableDatabase
{
    __block LYRDatabaseProxy *databaseProxy = nil;
    dispatch_semaphore_wait(self.poolSemaphore, DISPATCH_TIME_FOREVER);
    dispatch_sync(self.collectionGuardSerialQueue, ^{
        FMDatabase *availableDatabase = [[self availableDatabases] anyObject];
        if (!availableDatabase) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Failed to obtain an available database reference, but one should be available: resource management is out of sync." userInfo:nil];
        }
        
        databaseProxy = [[LYRDatabaseProxy alloc] initWithDatabase:availableDatabase semaphore:self.poolSemaphore];
        [self.busyDatabases addObject:databaseProxy];
    });
    return (FMDatabase *)databaseProxy;
}

- (void)releaseDatabase:(FMDatabase *)database
{
    dispatch_sync(self.collectionGuardSerialQueue, ^{
        LYRDatabaseProxy *proxyToRelease = nil;
        for (LYRDatabaseProxy *proxy in self.busyDatabases) {
            if (proxy == (LYRDatabaseProxy *)database) {
                proxyToRelease = proxy;
                break;
            }
        }
        
        if (proxyToRelease) {
            [database closeOpenResultSets];
            [self.busyDatabases removeObject:proxyToRelease];
            [proxyToRelease __signalSemaphore];
        }
    });
}

- (void)inDatabase:(void (^)(FMDatabase *database))block
{
    FMDatabase *database = [self waitForAvailableDatabase];
    block(database);
    [self releaseDatabase:database];
}

- (NSUInteger)numberOfDatabases
{
    return [self.pool count];
}

- (NSUInteger)numberOfAvailableDatabases
{
    return self.numberOfDatabases - [[self.busyDatabases allObjects] count];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len
{
    return [self.pool countByEnumeratingWithState:state objects:buffer count:len];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@:%p capacity=%lu busyConnections=%lu>", [self class], self, (unsigned long)self.pool.count, (unsigned long)[self.busyDatabases allObjects].count];
}

@end
