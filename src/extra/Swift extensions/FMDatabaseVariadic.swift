//
//  FMDatabaseVariadic.swift
//  FMDB
//


//  This extension inspired by http://stackoverflow.com/a/24187932/1271826

import Foundation

extension FMDatabase {

    /// This is a rendition of executeQuery that handles Swift variadic parameters
    /// for the values to be bound to the ? placeholders in the SQL.
    ///
    /// :param: sql The SQL statement to be used.
    /// :param: values The values to be bound to the ? placeholders
    ///
    /// :returns: This returns FMResultSet if successful. Returns nil upon error.

    func executeQuery(sql:String, _ values: NSArray...) -> FMResultSet? {
        return executeQuery(sql, withArgumentsInArray: values);
    }

    /// This is a rendition of executeUpdate that handles Swift variadic parameters
    /// for the values to be bound to the ? placeholders in the SQL.
    ///
    /// :param: sql The SQL statement to be used.
    /// :param: values The values to be bound to the ? placeholders
    ///
    /// :returns: This returns true if successful. Returns false upon error.

    func executeUpdate(sql:String, _ values: NSArray...) -> Bool {
        return executeUpdate(sql, withArgumentsInArray: values);
    }
}
