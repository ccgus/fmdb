//
//  FMDatabase+Introspection.h
//  NumberStation
//
//  Created by Todd Blanchard on 3/20/14.
//
//

#import "FMDatabase.h"

@interface FMDatabase (Introspection)

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
