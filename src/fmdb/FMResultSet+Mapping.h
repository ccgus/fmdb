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

#import <Foundation/Foundation.h>
#import "FMResultSet.h"

@protocol FMRowMapper;
@protocol FMResultSetExtractor;

@interface FMResultSet (Mapping)


/**
* Returns an array where for each item in the result set, iterates mapping each row onto a domain entity type.
*
* The result set is closed upon completion.
*/
- (NSArray *)mapWith:(id<FMRowMapper>)mapper;

/**
* Maps the entire result set onto an arbitrary object. Unlike FMRowMapper it is necessary to iterate over the result set
* whereas FMRowMapper provides an interface for mapping a single row to a domain model object, therefore FMRowMapper
* is generally the simpler choice. FMResultSetExtractor is useful for example to map a one-to-many using a single SQL
* query.
*
* The result set is closed upon completion.
*/
- (id)extractWith:(id<FMResultSetExtractor>)extractor;

@end