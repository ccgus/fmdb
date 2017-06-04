//
//  FMDatabaseQueue+Introspection.h
//  PokeLab
//
//  Created by Todd Blanchard on 9/6/16.
//  Copyright © 2016 Todd Blanchard. All rights reserved.
//

#import "FMDatabaseQueue.h"

@interface FMDatabaseQueue (Introspection)

- (NSArray*)tablenames;
- (BOOL)tableExists:(NSString*)tableName;

/*
 get table with list of tables: result colums: type[STRING], name[STRING],tbl_name[STRING],rootpage[INTEGER],sql[STRING]
 check if table exist in database  (patch from OZLB)
 */
- (NSArray*)getSchema;

/*
 get table schema: result colums: cid[INTEGER], name,type [STRING], notnull[INTEGER], dflt_value[],pk[INTEGER]
 */
- (NSArray*)getTableSchema:(NSString*)tableName;

- (BOOL)columnExists:(NSString*)columnName inTableWithName:(NSString*)tableName;

// return a dictionary with tablenames as keys and sql statement to create the table -tb
- (NSDictionary*)createScripts;


@end
