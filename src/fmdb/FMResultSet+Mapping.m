////////////////////////////////////////////////////////////////////////////////
//
//  fmdb
//
//  NOTICE: The authors permit you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////



#import "FMResultSet+Mapping.h"
#import "FMRowMapper.h"
#import "FMResultSetExtractor.h"
#import "FMDatabase.h"


@implementation FMResultSet (Mapping)

- (NSArray *)mapWith:(id<FMRowMapper>)mapper
{
    NSMutableArray *results = [NSMutableArray array];
    while ([self next]) {
        id mappedRow = [mapper mapRow:[results count] inResultSet:self];
        [results addObject:mappedRow];
    }
    [self close];
    //Return an immutable copy.
    return [results copy];

}

- (id)extractWith:(id<FMResultSetExtractor>)extractor
{
    id extracted = [extractor extractData:self];
    [self close];
    return extracted;
}


@end