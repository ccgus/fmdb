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
    /// This throws any error that occurs.
    ///
    /// - parameter sql:     The SQL statement to be used.
    /// - parameter values:  The values to be bound to the ? placeholders
    ///
    /// - returns:           This returns FMResultSet if successful. If unsuccessful, it throws an error.
    
    func executeQuery(sql:String, _ values: AnyObject...) throws -> FMResultSet {
        return try executeQuery(sql, values: values as [AnyObject]);
    }
    
    /// This is a rendition of executeUpdate that handles Swift variadic parameters
    /// for the values to be bound to the ? placeholders in the SQL.
    ///
    /// This throws any error that occurs.
    ///
    /// - parameter sql:     The SQL statement to be used.
    /// - parameter values:  The values to be bound to the ? placeholders
    
    func executeUpdate(sql:String, _ values: AnyObject...) throws {
        try executeUpdate(sql, values: values as [AnyObject]);
    }
}
