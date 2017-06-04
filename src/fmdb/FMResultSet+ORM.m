//
//  EGODatabaseResult+ORM.m
//  NumberStation
//
//  Created by Todd Blanchard on 3/20/14.
//
//

#import "FMResultSet+ORM.h"
#import "FMDatabase.h"

#if FMDB_SQLITE_STANDALONE
#import <sqlite3/sqlite3.h>
#else
#import <sqlite3.h>
#endif

@implementation FMResultSet (ORM)

- (NSArray*)objectsOfClass:(Class)c
{
    NSMutableArray* newRows = [NSMutableArray array];
    while([self next])
    {
        [newRows addObject: [self objectOfClass:c]];
    }
    return newRows;
}

- (NSArray*)objectsOfClass:(Class)c mappings:(NSDictionary*)d
{
    NSMutableArray* newRows = [NSMutableArray array];
    while([self next])
    {
        [newRows addObject: [self objectOfClass:c mappings:d]];
    }
    return newRows;
}

- (NSArray*)resultDictionaries
{
    NSMutableArray* newRows = [NSMutableArray array];
    while([self next])
    {
        [newRows addObject: [self resultDictionary]];
    }
    return newRows;
}

- (id)populateObject:(id)obj
{
    [self kvcMagic:obj];
    return obj;
}

-(id)populateObject:(id)obj mappings:(NSDictionary*)d
{
    int columnCount = sqlite3_column_count([_statement statement]);
    
    int columnIdx = 0;
    for (columnIdx = 0; columnIdx < columnCount; columnIdx++) {
        
        const char *c = (const char *)sqlite3_column_text([_statement statement], columnIdx);
        
        // check for a null row
        if (c) 
        {
            NSString *s = [NSString stringWithUTF8String:c];    
            [obj setValue:s forKey:d[[NSString stringWithUTF8String:sqlite3_column_name([_statement statement], columnIdx)]]];
        }
    }
    return obj;
}

- (id)objectOfClass:(Class)c
{
    id obj = [[c alloc]init];
    return [self populateObject:obj];
}

- (id)objectOfClass:(Class)c mappings:(NSDictionary*)d
{
    id obj = [[c alloc]init];
    return [self populateObject:obj mappings:d];
}

@end
