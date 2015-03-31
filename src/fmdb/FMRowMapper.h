////////////////////////////////////////////////////////////////////////////////
//
//  NOTICE: The authors permit you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////


#import <Foundation/Foundation.h>

@class FMResultSet;

/**
* Iterates over the result set mapping each row onto a domain entity type.
*/
@protocol FMRowMapper<NSObject>

- (id)mapRow:(NSUInteger)rowNumber inResultSet:(FMResultSet *)resultSet;

@end