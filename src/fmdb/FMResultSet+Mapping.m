////////////////////////////////////////////////////////////////////////////////
//
//  CODE MONASTERY
//  Copyright 2015 Code Monastery Pty Ltd
//  All Rights Reserved.
//
//  NOTICE: Prepared by AppsQuick.ly on behalf of Code Monastery. This software
//  is proprietary information. Unauthorized use is prohibited.
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
    //Return an immutable copy.
    [self close];
    return [results copy];

}

- (id)extractWith:(id<FMResultSetExtractor>)extractor
{
    id extracted = [extractor extractData:self];
    FMDBAutorelease(extracted);
    [self close];
    return extracted;
}


@end