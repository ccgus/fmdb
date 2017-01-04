//
//  FMResultSet Extension.swift
//

import Foundation

extension FMResultSet {

    ///A map function to replace `resultSet.next()`
    func map<T>(transform: FMResultSet -> T) -> [T] {
        var results: [T] = []
        while self.next() {
            results.append(transform(self))
        }
        return results
    }
    
}