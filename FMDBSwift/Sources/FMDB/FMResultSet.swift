
import Foundation
import SQLite3

public class FMResultSet : NSObject {
    var parentDB : FMDatabase?
    var statement : FMStatement?
    var shouldAutoClose = true
    
    var _columnNameToIndexMap : [String: Int32]?
    
    
    static func resultSet(withStatement:FMStatement, parentDatabase:FMDatabase, shouldAutoClose: Bool) -> FMResultSet {
        
        let rs = FMResultSet()
        
        rs.parentDB = parentDatabase
        rs.statement = withStatement
        rs.shouldAutoClose = shouldAutoClose
        
        assert(!rs.statement!._inUse)
        withStatement._inUse = true
        
        return rs
    }
    
    public override init() {
        
        
        
    }
    
    
    deinit {
        close()
    }
    
    public func close() {
        statement?.reset()
        
        statement = nil
        
        parentDB?.resultSetDidClose(resultSet: self)
        
        parentDB = nil
    }
    
    
    public func columnCount() -> Int32 {
        return sqlite3_column_count(statement?._statement);
    }
    
    
    
    @discardableResult public func next() throws -> Bool  {
        
        let rc = try internalStep()
        
        return rc == SQLITE_ROW;
        
    }
    
    func internalStep() throws -> Int32 {
        
        let rc = sqlite3_step(statement?._statement);
        
        var err : NSError?
        // … stuff
        
        if (SQLITE_BUSY == rc || SQLITE_LOCKED == rc) {
            print("Database busy ", #function, #line, parentDB?._databasePath! as Any)
            print("Database busy");
            err = NSError(domain: "FMDatabase", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: parentDB?.lastErrorMessage() ?? "Unknown"]);
        }
        else if (SQLITE_DONE == rc || SQLITE_ROW == rc) {
            // all is well, let's return.
        }
        else if (SQLITE_ERROR == rc) {
            err = parentDB?.lastError()
            print("Error calling sqlite3_step ", err as Any)
        }
        else if (SQLITE_MISUSE == rc) {
            // uh oh.
            
            print("Error calling sqlite3_step ", rc, sqlite3_errmsg(parentDB?.sqliteHandle()) as Any);
            
            if (parentDB != nil) {
                err = parentDB?.lastError()
            }
            else {
                // If 'next' or 'nextWithError' is called after the result set is closed,
                // we need to return the appropriate error.
                err = NSError(
                        domain: "FMDatabase",
                        code: Int(SQLITE_MISUSE),
                        userInfo: [
                            NSLocalizedDescriptionKey: "parentDB does not exist"
                        ]
                    )
            }
        }
        else {
            // wtf?
            print("Unknown error calling sqlite3_step ", rc, sqlite3_errmsg(parentDB?.sqliteHandle()) as Any);

            err = parentDB?.lastError()
        }

        if (rc != SQLITE_ROW && shouldAutoClose) {
            close()
        }
        
        if let err = err {
            throw FMDBError.sqlite3ErrorCode(Int32(err.code))
        }
        
        return rc
    }
    
    func hasAnotherRow() -> Bool {
        return sqlite3_errcode(parentDB?.sqliteHandle()) == SQLITE_ROW;
        
    }
    
    
    func string(_ columnIndex: Int32) -> String? {
        
        if (sqlite3_column_type(statement?._statement, columnIndex) == SQLITE_NULL || (columnIndex < 0) || columnIndex >= sqlite3_column_count(statement?._statement)) {
            return nil;
        }
        
        let c = sqlite3_column_text(statement?._statement, columnIndex)
        
        if (c == nil) {
            return nil;
        }
        
        return String.init(cString: c!);
        
    }
    
    func string(_ columnName: String) -> String?  {
        
        let columnIndex = columnIndexForName(columnName)
        if (columnIndex >= 0) {
            return string(columnIndex)
        }
        
        return nil
        
    }
    
    func UTF8String(_ columnIndex: Int32) -> UnsafePointer<UInt8>! {
        if (sqlite3_column_type(statement?._statement, columnIndex) == SQLITE_NULL || (columnIndex < 0) || columnIndex >= sqlite3_column_count(statement?._statement)) {
            return nil;
        }
        
        return sqlite3_column_text(statement?._statement, columnIndex)
    }
    
    
    func UTF8String(_ columnName: String) -> UnsafePointer<UInt8>! {
        
        let columnIndex = columnIndexForName(columnName)
        if (columnIndex >= 0) {
            return UTF8String(columnIndex)
        }
        
        return nil
    }
    
    
    func longLongInt(_ columnIndex: Int32) -> Int64 {
        return sqlite3_column_int64(statement?._statement, columnIndex);
    }
    
    func longLongInt(_ columnName: String) -> Int64 {
        
        let columnIndex = columnIndexForName(columnName)
        if (columnIndex >= 0) {
            return longLongInt(columnIndex)
        }
        
        print("Could not find column index for \(columnName)")
        
        return 0
    }
    
    func unsignedLongLongInt(_ columnIndex: Int32) -> UInt64 {
        return UInt64(truncatingIfNeeded: sqlite3_column_int64(statement?._statement, columnIndex));
    }
    
    func unsignedLongLongInt(_ columnName: String) -> UInt64 {
        
        let columnIndex = columnIndexForName(columnName)
        if (columnIndex >= 0) {
            return unsignedLongLongInt(columnIndex)
        }
        
        print("Could not find column index for \(columnName)")
        
        return 0
    }
    
    func int(_ columnIndex: Int32) -> Int32 {
        return sqlite3_column_int(statement?._statement, columnIndex);
    }
    
    
    func int(_ columnName: String) -> Int32 {
        
        let columnIndex = columnIndexForName(columnName)
        if (columnIndex >= 0) {
            return int(columnIndex)
        }
        
        print("Could not find column index for \(columnName)")
        
        return 0
    }
    
    // FIXME: Should 'bool' be renamed to 'boolean'?
    func bool(_ columnIndex: Int32) -> Bool {
        return int(columnIndex) != 0
    }
    
    func bool(_ columnName: String) -> Bool {
        return int(columnName) != 0
    }
    
    
    func double(_ columnIndex: Int32) -> Double {
        return sqlite3_column_double(statement?._statement, columnIndex);
    }
    
    func double(_ columnName: String) -> Double {
        
        let columnIndex = columnIndexForName(columnName)
        if (columnIndex >= 0) {
            return double(columnIndex);
        }
        
        return 0.0
    }
    
    func date(_ columnIndex: Int32) -> NSDate? {
        
        if (sqlite3_column_type(statement?._statement, columnIndex) == SQLITE_NULL || (columnIndex < 0) || columnIndex >= sqlite3_column_count(statement?._statement)) {
            return nil;
        }
        
        #warning("need to check for date formatters in dateForColumnIndex?")
        // return [_parentDB hasDateFormatter] ? [_parentDB dateFromString:[self stringForColumnIndex:columnIndex]] : [NSDate dateWithTimeIntervalSince1970:[self doubleForColumnIndex:columnIndex]];
        
        return NSDate.init(timeIntervalSince1970: double(columnIndex))
        
    }
    
    func date(_ columnName: String) -> NSDate? {
        
        let columnIndex = columnIndexForName(columnName)
        if (columnIndex >= 0) {
            return date(columnIndex);
        }
        
        return nil
    }
    
    
    func data(_ columnIndex: Int32) -> Data? {
        
        if (sqlite3_column_type(statement?._statement, columnIndex) == SQLITE_NULL || (columnIndex < 0) || columnIndex >= sqlite3_column_count(statement?._statement)) {
            return nil;
        }
        
        let dataBuffer = sqlite3_column_blob(statement?._statement, columnIndex);
        let dataSize = sqlite3_column_bytes(statement?._statement, columnIndex);

        if (dataBuffer == nil) {
            return nil
        }
        
        let d = NSData(bytes:dataBuffer, length: Int(dataSize))
        
        return d as Data
        
    }
    
    func data(_ columnName: String) -> Data? {
        
        let columnIndex = columnIndexForName(columnName)
        if (columnIndex >= 0) {
            return data(columnIndex);
        }
        
        return nil
    }
    
    func dataNoCopy(_ columnIndex: Int32) -> Data? {
        
        if (sqlite3_column_type(statement?._statement, columnIndex) == SQLITE_NULL || (columnIndex < 0) || columnIndex >= sqlite3_column_count(statement?._statement)) {
            return nil;
        }
        
        let dataBuffer = sqlite3_column_blob(statement?._statement, columnIndex);
        let dataSize = sqlite3_column_bytes(statement?._statement, columnIndex);

        if (dataBuffer == nil) {
            return nil
        }
        
        guard let dataBufferPointer = UnsafeMutableRawPointer(mutating:dataBuffer) else { return nil }
        
        let d = NSData(bytesNoCopy: dataBufferPointer, length: Int(dataSize), freeWhenDone: false)
                       
        return d as Data
        
    }
    
    func dataNoCopy(_ columnName: String) -> Data? {
        
        let columnIndex = columnIndexForName(columnName)
        if (columnIndex >= 0) {
            return dataNoCopy(columnIndex);
        }
        
        return nil
    }
    
    
    /*
     - (NSMutableDictionary *)columnNameToIndexMap {
         if (!_columnNameToIndexMap) {
             int columnCount = sqlite3_column_count([_statement statement]);
             _columnNameToIndexMap = [[NSMutableDictionary alloc] initWithCapacity:(NSUInteger)columnCount];
             int columnIndex = 0;
             for (columnIndex = 0; columnIndex < columnCount; columnIndex++) {
                 [_columnNameToIndexMap setObject:[NSNumber numberWithInt:columnIndex]
                                           forKey:[[NSString stringWithUTF8String:sqlite3_column_name([_statement statement], columnIndex)] lowercaseString]];
             }
         }
         return _columnNameToIndexMap;
     }
     */
    
    func columnNameToIndexMap() -> Dictionary<String, Int32> {
        
        
        
        if (_columnNameToIndexMap == nil) {
            
            let columnCount = sqlite3_column_count(statement?._statement);
            _columnNameToIndexMap = Dictionary()
            
            var columnIndex = Int32(0);
            while (columnIndex < columnCount) {
                
                let c = sqlite3_column_name(statement?._statement, columnIndex)
                
                let s = String.init(cString: c!).lowercased()
                
                _columnNameToIndexMap?[s] = columnIndex
                
                columnIndex += 1
            }
        }

        
        return _columnNameToIndexMap ?? [:]
    }
    
    
    func columnIndexForName( _ columnName : String) -> Int32 {
        
        let lowerName = columnName.lowercased()
        
        let n = columnNameToIndexMap()[lowerName]
        
        if (n == nil) {
            print("Warning: I could not find the column named '" + columnName + "'.");
        }
        
        return Int32(n ?? -1)
    }
    
    func columnNameForIndex(_ columnIndex : Int32) -> String {
        
        let c = sqlite3_column_name(statement?._statement, columnIndex)
        
        return String.init(cString: c!)
    }
    
    
    func typeForColumn(_ columnName:String) -> Int32 {
        
        let columnIndex = columnIndexForName(columnName)
        if (columnIndex >= 0) {
            return sqlite3_column_type(statement?._statement, columnIndex);
        }
        
        return 0
    }
    
    func typeForColumnIndex(_ columnIndex:Int32) -> Int32 {
        return sqlite3_column_type(statement?._statement, columnIndex);
    }
    
    
    
    func columnIsNull(_ columnName:String) -> Bool {
        return columnIsNull(columnIndexForName(columnName))
    }
    
    func columnIsNull(_ columnIndex:Int32) -> Bool {
        
        if (columnIndex >= 0) {
            return sqlite3_column_type(statement?._statement, columnIndex)  == SQLITE_NULL;
        }
        
        return false
    }
    
    
    subscript(columnIndex: Int32) -> Any? {
        
        var returnValue : Any?
        
        let columnType = sqlite3_column_type(statement?._statement, columnIndex);
        
        
        if (columnType == SQLITE_INTEGER) {
            returnValue = longLongInt(columnIndex)
        }
        else if (columnType == SQLITE_FLOAT) {
            returnValue = double(columnIndex)
        }
        else if (columnType == SQLITE_BLOB) {
            returnValue = data(columnIndex)
        }
        else {
            //default to a string for everything else
            returnValue = string(columnIndex)
        }
  
        // FMDB in ObjC returns NSNull here. But… do we really need to do that anymore?
//        if (returnValue == nil) {
//            returnValue = NSNull()
//        }
        
        return returnValue
    }
    
    subscript(columnName: String) -> Any? {
        
        let columnIndex = columnIndexForName(columnName)
        if (columnIndex < 0 || columnIndex >= sqlite3_column_count(statement?._statement)) {
            return nil
        }
        
        return self[columnIndex]
    }
    
    
    func resultDictionary() -> Dictionary<String, Any> {
        
        if (sqlite3_data_count(statement?._statement) > 0) {
            
            var dict = [String: Any]()
            
            // FIXME: why do we use sqlite3_column_count here, but sqlite3_data_count above? Maybe add a comment as to why?
            let columnCount = sqlite3_column_count(statement?._statement);
            
            var columnIndex = Int32(0);
            while (columnIndex < columnCount) {
                
                let name = columnNameForIndex(columnIndex)
                let objVale = self[name]
                
                dict[name] = objVale
                
                columnIndex = columnIndex + 1
            }
            
            return dict
        }
        
        return [:]
    }
    
}
