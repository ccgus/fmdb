////////////////////////////////////////////////////////////////////////////////
//
//  fmdb
//
//  NOTICE: The authors permit you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////



#import <Foundation/Foundation.h>

@class FMResultSet;

/**
* Maps the entire result set onto an arbitrary object. Unlike FMRowMapper it is necessary to iterate over the result set
* whereas FMRowMapper provides an interface for mapping a single row to a domain model object, therefore FMRowMapper
* is generally the simpler choice. FMResultSetExtractor is useful for example to map a one-to-many using a single SQL
* query.
*
* Under manual memory management an autoreleased object should be returned.
*/
@protocol FMResultSetExtractor<NSObject>

- (id)extractData:(FMResultSet *)resultSet;

@end