//
//  FMDatabaseQueue+Introspection.m
//  PokeLab
//
//  Created by Todd Blanchard on 9/6/16.
//  Copyright © 2016 Todd Blanchard. All rights reserved.
//

#import "FMDatabaseQueue+Introspection.h"
#import "FMResultSet+ORM.h"
#import "FMDatabase.h"

@implementation FMDatabaseQueue (Introspection)

- (NSArray*)tablenames
{
    return [[NSSet setWithArray:[[self getSchema]valueForKeyPath:@"tbl_name"]]allObjects];
}

- (BOOL)tableExists:(NSString*)tableName
{
    BOOL __block exists = NO;
     [self inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"select [sql] from sqlite_master where [type] = 'table' and lower(name) = ?", [tableName lowercaseString],nil];
         exists = [[rs resultDictionaries]count] > 0;
    }];
    return exists;
}

/*
 get table with list of tables: result colums: type[STRING], name[STRING],tbl_name[STRING],rootpage[INTEGER],sql[STRING]
 check if table exist in database  (patch from OZLB)
 */
- (NSArray*)getSchema
{
    NSArray* __block schema = nil;
    //result colums: type[STRING], name[STRING],tbl_name[STRING],rootpage[INTEGER],sql[STRING]
    [self inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT type, name, tbl_name, rootpage, sql FROM (SELECT * FROM sqlite_master UNION ALL SELECT * FROM sqlite_temp_master) WHERE type != 'meta' AND name NOT LIKE 'sqlite_%' ORDER BY tbl_name, type DESC, name"];
        schema = [rs resultDictionaries];
    }];
    return schema;
}

/*
 get table schema: result colums: cid[INTEGER], name,type [STRING], notnull[INTEGER], dflt_value[],pk[INTEGER]
 */
- (NSArray*)getTableSchema:(NSString*)tableName
{
    NSArray* __block schema = nil;
    //result colums: cid[INTEGER], name,type [STRING], notnull[INTEGER], dflt_value[],pk[INTEGER]
    [self inDatabase:^(FMDatabase *db) {
        FMResultSet* rs = [db executeQueryWithFormat:@"pragma table_info('%@')", tableName];
        schema = [rs resultDictionaries];
    }];
    return schema;
}

- (BOOL)columnExists:(NSString*)columnName inTableWithName:(NSString*)tableName
{
    tableName  = [tableName lowercaseString];
    columnName = [columnName lowercaseString];
    
    NSArray *rs = [self getTableSchema:tableName];
    
    //check if column is present in table schema
    for(NSDictionary* row in rs)
    {
        if([[row[@"name"] lowercaseString] isEqualToString:columnName])
        {
            return YES;
        }
    }
    return NO;
}

-(NSDictionary*)createScripts
{
    NSDictionary* __block scripts = nil;
    [self inDatabase:^(FMDatabase *db) {
        FMResultSet* rs = [db executeQuery:@"select name, sql from sqlite_master where type='table' ORDER BY name"];
        NSArray* rows = [rs resultDictionaries];
        scripts = [NSDictionary dictionaryWithObjects:[rows valueForKey:@"sql"] forKeys:[rows valueForKey:@"name"]];
    }];
    return scripts;
}


@end
