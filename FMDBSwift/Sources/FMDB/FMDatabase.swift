
import Foundation
import SQLite3


// Why the f doesn't this show up in the sqlite3.h headers for swift?
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

#warning("Should we give this a better name? It's not very FMDB-like")

enum SqliteValueType : Int32 {
    case SqliteValueTypeInteger = 1,
         SqliteValueTypeFloat   = 2,
         SqliteValueTypeText    = 3,
         SqliteValueTypeBlob    = 4,
         SqliteValueTypeNull    = 5
}


/*
 // These are from the sqlite3 headers.
#define SQLITE_INTEGER  1
#define SQLITE_FLOAT    2
#define SQLITE3_TEXT    3
#define SQLITE_BLOB     4
#define SQLITE_NULL     5
 
*/

enum FMDBError: Error {
    case sqlite3ErrorCode(Int32)
}

public class FMDatabase : NSObject {
  
    private var _db : OpaquePointer?
    var _databasePath : String?
    private var _isOpen : Bool
    private var _maxBusyRetryTimeInterval : TimeInterval = 2
    private var _startBusyRetryTime : TimeInterval = 0
    public var logsErrors : Bool
    private var _shouldCacheStatements = false
    private var _openResultSets : Array<FMResultSet>
    private var _cachedStatements : Dictionary<String, Set<FMStatement>>?
    private var _isInTransaction = false
    private var _isExecutingStatement = false
    public var crashOnErrors = false
    public var traceExecution = true
    
    
    #warning("We need to port over all instances of _isExecutingStatement")
    
    public override init() {
        
        _isOpen = false
        
        _databasePath = ":memory:"
        
        _openResultSets = Array<FMResultSet>()
        
        logsErrors = true
        
    }
    
    static func isSQLiteThreadSafe() -> Bool {
        // make sure to read the sqlite headers on this guy!
        return sqlite3_threadsafe() != 0;
    }
    
    static func database(with filePath : String) -> FMDatabase {
        
        let db = FMDatabase()
        db._databasePath = filePath
        
        return db
    }
    
    static func database(with fileURL : URL) -> FMDatabase {
        return FMDatabase.database(with: fileURL.path)
    }
    
    
    func databaseURL() -> NSURL? {
        return (_databasePath != nil) ? NSURL(fileURLWithPath: _databasePath!) : nil
        //[NSURL fileURLWithPath:_databasePath] : nil;
    }
    
    // MARK: Cached statements
    
    public func clearCachedStatements() {
        
        if var unwrappedCachedStatements = _cachedStatements {
            
            for (_, statementSet) in unwrappedCachedStatements {
                for (statement) in statementSet {
                    statement.close()
                }
            }
            
            unwrappedCachedStatements.removeAll()
        }
    }
    
    func cachedStatementForQuery(_ query : String) -> FMStatement? {
        
        if let uwCachedStatements = _cachedStatements {
            
            let setOfStatements = uwCachedStatements[query] // Dictionary<String, Set<FMStatement>>?
            let st = setOfStatements?.first(where: { st in
                !st._inUse
            })
            
            return st
        }
        
        return nil
    }
    
    func setCachedStatement(_ statement : FMStatement, forQuery: String) {
        
        statement._query = forQuery
        
        if var uwCachedStatements = _cachedStatements {
            var statements = uwCachedStatements[forQuery]
            if (statements == nil) {
                statements = Set<FMStatement>()
                uwCachedStatements[forQuery] = statements
            }
            
            statements?.insert(statement)
        }
    }
    
    func shouldCacheStatements() -> Bool {
        return _shouldCacheStatements
    }
    
    func setShouldCacheStatements(_ flag: Bool) {
        _shouldCacheStatements = flag
        if (_shouldCacheStatements && _cachedStatements != nil) {
            _cachedStatements = Dictionary<String, Set<FMStatement>>()
        }
        
        if (!_shouldCacheStatements) {
            _cachedStatements = nil
        }
    }
    
    
    public func hasOpenResultSets() -> Bool {
        return _openResultSets.count > 0
    }
    
    public func closeOpenResultSets() {
        
        
        for rs in (_openResultSets as NSArray as! [FMResultSet]) {
            
            rs.parentDB = nil // nil it out so close doesn't call resultSetDidClose
            rs.close()
            
        }
        
        _openResultSets.removeAll()
    }
    
    
    @discardableResult public func close() -> Bool {
        
        clearCachedStatements()
        closeOpenResultSets()
        
        var rc = SQLITE_ERROR
        var retry: Bool
        var triedFinalizingOpenStatements = false
        
        repeat {
            retry = false
            rc = sqlite3_close(_db)
            if (SQLITE_BUSY == rc || SQLITE_LOCKED == rc) {
                if (!triedFinalizingOpenStatements) {
                    triedFinalizingOpenStatements = true;
                    var pStmt : OpaquePointer?
                    pStmt = sqlite3_next_stmt(_db, nil)
                    while (pStmt != nil) {
                        print("Closing leaked statement")
                        sqlite3_finalize(pStmt);
                        pStmt = sqlite3_next_stmt(_db, nil)
                        retry = true;
                    }
                }
            }
            else if (SQLITE_OK != rc) {
                print("error closing!: %d", rc)
            }
        }
        while (retry)
        _db = nil
        _isOpen = false
                
        
        return SQLITE_OK == rc
    }
    
    @discardableResult public func open() throws -> Bool  {
        return try openWithFlags(flags: SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, vfsName: nil)
    }
    
    
    public func openWithFlags(flags : Int32, vfsName : String?) throws -> Bool {
        
        if (_isOpen) {
            return true
        }
        
        if (_db != nil) {
            close()
        }
        
        let err = sqlite3_open_v2(_databasePath, &_db, flags, vfsName)
        
        if (err != SQLITE_OK) {
            print("Error opening SQLite database: ", self.lastErrorMessage()!)
            throw FMDBError.sqlite3ErrorCode(err)
        }
        
        if (_maxBusyRetryTimeInterval > 0.0) {
            // set the handler
            setMaxBusyRetryTimeInterval(_maxBusyRetryTimeInterval);
        }
        
        _isOpen = true
        
        return true
    }
    
    
    func lastErrorMessage() -> String? {
        return String(utf8String: sqlite3_errmsg(_db))
    }
    
    func lastErrorCode() -> Int32 {
        return sqlite3_errcode(_db)
    }
    
    func lastExtendedErrorCode() -> Int32 {
        return sqlite3_extended_errcode(_db)
    }
    
    func error(withMessage: String) -> NSError {
        
        return NSError(
                domain: "FMDatabase",
                code: Int(sqlite3_errcode(_db)),
                userInfo: [
                    NSLocalizedDescriptionKey: withMessage
                ]
            )
        
    }
    
    
    func lastError() -> NSError {
        return self.error(withMessage: lastErrorMessage() ?? "")
    }
    
    func hadError() -> Bool {
        
        let lastErrCode = lastErrorCode()
        
        return (lastErrCode > SQLITE_OK && lastErrCode < SQLITE_ROW)
    }
    
    func databaseExists() ->Bool {
        
        if (!_isOpen) {
            
            print("The FMDatabase \(self) is not open.");
            
            if (crashOnErrors) {
                abort();
            }
            
            return false;
        }
        
        return true;
    }
    
    func internalBind(object: Any?, toColumn:Int32, statement: OpaquePointer?) -> Int32 {
        
        if object == nil || (object as? NSNull) != nil {
            return sqlite3_bind_null(statement, toColumn);
        }
        else if (object as? NSNull) != nil {
            return sqlite3_bind_null(statement, toColumn);
        }
        else if (object as? NSData) != nil {
            
            let d = object as? NSData
            
            let b = d?.bytes
            if (b == nil) {
                // it's an empty NSData object, aka [NSData data].
                // Don't pass a NULL pointer, or sqlite will bind a SQL null instead of a blob.
                
                // FIXME: This is pretty dumb.
                // This is just copied out of the swift book. I'm not sure what to pass here - but it can't be nil.
                let bytesPointer = UnsafeMutableRawPointer.allocate(byteCount: 4, alignment: 4)
                bytesPointer.storeBytes(of: 0xFFFF_FFFF, as: UInt32.self)
                
                return sqlite3_bind_blob(statement, toColumn, bytesPointer, 0, SQLITE_TRANSIENT);
            }
            
            return sqlite3_bind_blob(statement, toColumn, b, Int32(d?.length ?? 0), SQLITE_TRANSIENT);
            
        }
        else if let object = object as? String {
            return sqlite3_bind_text(statement, toColumn, object, -1, SQLITE_TRANSIENT)
        }
        else if let object = object as? Double {
            return sqlite3_bind_double(statement, toColumn, object)
        }
        else if let object = object as? Int64 {
            return sqlite3_bind_int64(statement, toColumn, object)
        }
        else if let object = object as? UInt64 {
            return sqlite3_bind_int64(statement, toColumn, Int64(truncatingIfNeeded:object))
        }
        else if let object = object as? Int32 {
            return sqlite3_bind_int(statement, toColumn, object)
        }
        else if let object = object as? UInt32 {
            return sqlite3_bind_int(statement, toColumn, Int32(object))
        }
        else if let object = object as? Int {
            return sqlite3_bind_int(statement, toColumn, Int32(object))
        }
        else if let object = object as? Bool {
            return sqlite3_bind_int(statement, toColumn, object ? 1 : 0)
        }
        else if let object = object as? Date {
            
            #warning("Need to check for a date formatter when binding")
            
//            if (self.hasDateFormatter)
//                return sqlite3_bind_text(pStmt, idx, [[self stringFromDate:obj] UTF8String], -1, SQLITE_TRANSIENT);
//            else
            
            return sqlite3_bind_double(statement, toColumn, object.timeIntervalSince1970);
        }
        
        print("unknown type: ", type(of: object))
        
        #warning("These types are all well and good, but FMDB supports much much more. Port them all over, Gus")

        return SQLITE_ERROR
    }
    
    func bind(statement: FMStatement, argArray: Array<Any?>?, argDict: Dictionary<String, Any?>?) throws -> Bool {
        
        var idx = Int(0)
        let queryCount = sqlite3_bind_parameter_count(statement._statement); // pointed out by Dominic Yu (thanks!)
        
        
        if let uwArgDict = argDict {
            
            for (k, obj) in uwArgDict {
                
                // Prefix the key with a colon.
                let parameterName = ":\(k)"
                
                // Get the index for the parameter name.
                let namedIdx = sqlite3_bind_parameter_index(statement._statement, parameterName);

                if (namedIdx > 0) {
                    // Standard binding from here.
                    
                    
                    if (traceExecution) {
                        print("Index \(namedIdx), \(k) = \(obj ?? "nil")")
                    }

                    
                    let rc = internalBind(object: obj, toColumn: Int32(namedIdx), statement: statement._statement ?? nil)
                    if (rc != SQLITE_OK) {
                        
                        let errString = lastErrorMessage()
                        print("Error: unable to bind (\(rc), \(errString ?? "")")
                        // #define SQLITE_RANGE       25   /* 2nd parameter to sqlite3_bind out of range */
                        
                        _isExecutingStatement = false
                        
                        throw FMDBError.sqlite3ErrorCode(rc)
                    }
                    
                    
                    // increment the binding count, so our check below works out
                    idx = idx + 1;
                }
                else {
                    print("Could not find index for \(k)");
                }
            }
            
        }
        else if let uwArgArray = argArray {
            
            while (idx < queryCount) {
                
                if (idx >= uwArgArray.count) {
                    //We ran out of arguments
                    break;
                }
                
                let obj = uwArgArray[idx]
                
                idx += 1
                
                let rc = internalBind(object: obj, toColumn: Int32(idx), statement: statement._statement ?? nil)
                if (rc != SQLITE_OK) {
                    
                    print("Error: unable to bind (\(rc), \(String(describing: sqlite3_errmsg(_db)))")
                    
                    _isExecutingStatement = false
                    
                    sqlite3_finalize(statement._statement);
                    throw FMDBError.sqlite3ErrorCode(rc)
                }
                
                
            }
        }
        
        
        if (idx != queryCount) {
            print("Error: the bind count is not correct for the # of variables (executeQuery)");
            assert(false, "Error: the bind count is not correct for the # of variables (executeQuery)")
//            sqlite3_finalize(pStmt);
//            pStmt = 0x00;
//            _isExecutingStatement = NO;
//            return false;
        }
        
        
        
        return true
    }
    
    
    
    
    @discardableResult func executeQuery(_ sql : String, argArray : [Any?]?, argDictionary : Dictionary<String, Any?>?, shouldBind: Bool) throws -> FMResultSet {
        
        if (!databaseExists()) {
            throw FMDBError.sqlite3ErrorCode(-1)
        }
        
        if (_isExecutingStatement) {
            warnInUse();
            throw FMDBError.sqlite3ErrorCode(-1)
        }
        
        _isExecutingStatement = true
        
        let rc : Int32
        var pStmt : OpaquePointer?
        var statement : FMStatement?
        
        if (_shouldCacheStatements) {
            statement = cachedStatementForQuery(sql)
            pStmt = statement != nil ? statement?._statement : nil
            statement?.reset()
        }
        
        
        if (pStmt == nil) {
            
            rc = sqlite3_prepare_v2(_db, sql, -1, &pStmt, nil)
            
            if (SQLITE_OK != rc) {
                if (logsErrors) {
                    print("DB Error: ", self.lastErrorCode(), self.lastErrorMessage()!);
                    print("DB Query: ", sql);
                    print("DB Path: ", _databasePath!);
                }
                
                sqlite3_finalize(pStmt);
                _isExecutingStatement = false
                
                throw FMDBError.sqlite3ErrorCode(rc)
            }
        }
        
        
        if (statement == nil) {
            statement = FMStatement()
            statement?._statement = pStmt
            
            if (_shouldCacheStatements) {
                setCachedStatement(statement!, forQuery: sql)
            }
            
        }
        
        
        if let uwArgArary = argArray {
            for item in uwArgArary {
                // FIXME: Can we check for arrays of any type?
                
                assert(type(of: item) != type(of: Array<Any>()), "We can't bind arrays in executeQuery (\(type(of: item)))")
            }
        }
        
        if (shouldBind) {
            
            
            if (try bind(statement: statement!, argArray: argArray, argDict: argDictionary)) {
                
            }
        }
//
//        var bindingItems = items
//
//        if (items.count == 1 && type(of: items[0]) == type(of: Array<Any>())) {
//            // need to unpack! We can't bind arrays and this was just passed down from another method
//            bindingItems = items[0] as! [Any]
//        }
//
//
//        if (try bind(statement: statement, usingArguments: bindingItems)) {
//
//        }
        
        let rs = FMResultSet.resultSet(withStatement: statement!, parentDatabase: self, shouldAutoClose: true);
        
        _openResultSets.append(rs)
        
        statement?.useCount = statement!.useCount + 1
        
        _isExecutingStatement = false;
        
        return rs;
    }
    
    @discardableResult func executeUpdate(_ sql : String, argArray:[Any?]?, argDictionary : Dictionary<String, Any?>?) throws -> Bool {
        
        var rs : FMResultSet
        
        do {
            rs = try self.executeQuery(sql, argArray: argArray, argDictionary:argDictionary, shouldBind:true)
        }
        catch {
            return false
        }
        
        var rc : Int32
        do {
        
            rc = try rs.internalStep()
        }
        catch {
            return false
        }
        
        return rc == SQLITE_DONE
            
    }

    
    
    @discardableResult func executeUpdate(_ sql : String, withParameterDictionary : Dictionary<String, Any>) throws -> Bool {
        
        return try executeUpdate(sql, argArray: nil, argDictionary: withParameterDictionary)
    }
    
    
    @discardableResult func executeQuery(_ sql : String, withParameterDictionary : Dictionary<String, Any>) throws -> FMResultSet {
        
        return try self.executeQuery(sql, argArray: nil, argDictionary:withParameterDictionary, shouldBind:true)
    }
    
    
    func pullSQLFromArgumnets(_ ar : [Any?]) -> (String, [Any?]) {
        
        if (ar.count < 1) {
            assert(false, "Empty array in pullSQLFromArgumnets")
        }
        
        let sql = ar[0] as! String
        
        assert(type(of: sql) == type(of: String()), "First argument is not a String, got \(type(of: sql))")
        
        var arx = Array(ar)
        arx.removeFirst()
        
        // Pop out an array from an array.
        if (arx.count == 1 && arx[0]! is Array<Any>) {
            arx = arx[0] as! [Any?]
        }
        
        return (sql, arx)
    }
    
    
    
    @discardableResult func executeUpdate(_ sqlStringAndBindings : Any?...) throws -> Bool {
        
        
        let (sql, args) = pullSQLFromArgumnets(sqlStringAndBindings)
        
        return try executeUpdate(sql, argArray: args, argDictionary: nil)
        
    }
    
    /*
    @discardableResult func executeUpdate(_ sql : String, items : Any...) throws -> Bool {
        
        if (!databaseExists()) {
            throw FMDBError.sqlite3ErrorCode(-1)
        }
        
        // print("type: ", type(of: items)) // type:  Array<Any>
        
        #warning("We need to unpack items if items[0] is an array")
        
        
        var pStmt : OpaquePointer?
        
        let rc = sqlite3_prepare_v2(_db, sql, -1, &pStmt, nil)
        
        if (SQLITE_OK != rc) {
            if (logsErrors) {
                print("DB Error: ", self.lastErrorCode(), self.lastErrorMessage()!);
                print("DB Query: ", sql);
                print("DB Path: ", _databasePath!);
            }
            
            
            sqlite3_finalize(pStmt);
            
            throw FMDBError.sqlite3ErrorCode(rc)
            
        }
        
        
        let statement = FMStatement()
        statement._statement = pStmt
        
        if (try bind(statement: statement, argArray: items, argDict: nil)) {
            
        }
        
        let rs = FMResultSet.resultSet(withStatement: statement, parentDatabase: self, shouldAutoClose: true);
        
        _openResultSets.append(rs)
        
        let stepCode = { return try? rs.internalStep() }()
        
        #warning("Should we just close out the rs here?")
        
        
        return stepCode == SQLITE_DONE;
    }
    */
    
    
    @discardableResult func executeQuery(_ sqlStringAndBindings : Any...) throws -> FMResultSet {
        
        
        let (sql, args) = pullSQLFromArgumnets(sqlStringAndBindings)
        
        return try executeQuery(sql, argArray: args, argDictionary: nil, shouldBind: true)
        
    }
    /*
    @discardableResult func executeQuery(_ sql : String, items : Any...) throws -> FMResultSet {
        
        if (!databaseExists()) {
            throw FMDBError.sqlite3ErrorCode(-1)
        }
        
        let rc : Int32
        var pStmt : OpaquePointer?
        
        rc = sqlite3_prepare_v2(_db, sql, -1, &pStmt, nil)
        
        if (SQLITE_OK != rc) {
            if (logsErrors) {
                print("DB Error: ", self.lastErrorCode(), self.lastErrorMessage()!);
                print("DB Query: ", sql);
                print("DB Path: ", _databasePath!);
            }
            
            
            sqlite3_finalize(pStmt);
            
            throw FMDBError.sqlite3ErrorCode(rc)
        }
        
        let statement = FMStatement()
        statement._statement = pStmt
        
        var bindingItems = items
        
        if (items.count == 1 && type(of: items[0]) == type(of: Array<Any>())) {
            // need to unpack! We can't bind arrays and this was just passed down from another method
            bindingItems = items[0] as! [Any]
        }
        
        
        if (try bind(statement: statement, argArray: bindingItems, argDict: nil)) {
            
        }
        
        let rs = FMResultSet.resultSet(withStatement: statement, parentDatabase: self, shouldAutoClose: true);
        
        _openResultSets.append(rs)
        
        return rs;
    }
    */
    
    public func setMaxBusyRetryTimeInterval(_ timeout : TimeInterval) {
        
        _maxBusyRetryTimeInterval = timeout
        
        if (_db == nil) {
            return
        }
        
        if (timeout > 0) {
            
            func handler(_ myself: UnsafeMutableRawPointer?, _ count: Int32) -> Int32 {
                
                let me  = unsafeBitCast(myself, to: FMDatabase.self)
                
                if (count == 0) {
                    me._startBusyRetryTime = NSDate().timeIntervalSinceReferenceDate
                    return 1;
                }
                
                
                let delta = NSDate().timeIntervalSinceReferenceDate - me._startBusyRetryTime
                
                if (delta < me._maxBusyRetryTimeInterval) {
                    let requestedSleepInMillseconds = arc4random_uniform(50) + 50;
                    let actualSleepInMilliseconds = sqlite3_sleep(Int32(requestedSleepInMillseconds));
                    
                    if (actualSleepInMilliseconds != requestedSleepInMillseconds) {
                        print("WARNING: Requested sleep of \(requestedSleepInMillseconds) milliseconds, but SQLite returned \(actualSleepInMilliseconds). Maybe SQLite wasn't built with HAVE_USLEEP=1?");
                    }
                    return 1;
                }
                
                return 0
            }
            
            
            sqlite3_busy_handler(_db, handler, unsafeBitCast(self, to: UnsafeMutableRawPointer.self));
        }
        else {
            // turn it off otherwise
            sqlite3_busy_handler(_db, nil, nil);
        }
    }
    
    func sqliteHandle() -> OpaquePointer? {
        return _db
    }
    
    
    func resultSetDidClose(resultSet: FMResultSet) {
        _openResultSets.removeAll(where: {$0 == resultSet})
    }
    
    @discardableResult func rollback() throws -> Bool {
        let b = try executeUpdate("rollback transaction")
        if (b) {
            _isInTransaction = false
        }
        return b
    }
    
    @discardableResult func commit() throws -> Bool {
        let b = try executeUpdate("commit transaction")
        if (b) {
            _isInTransaction = false
        }
        return b
    }
    
    @discardableResult func beginTransaction() throws -> Bool {
        return try beginExclusiveTransaction()
    }
    
    @discardableResult func beginDeferredTransaction() throws -> Bool {
        let b = try executeUpdate("begin deferred transaction")
        if (b) {
            _isInTransaction = true
        }
        return b
    }
    
    @discardableResult func beginImmediateTransaction() throws -> Bool {
        let b = try executeUpdate("begin immediate transaction")
        if (b) {
            _isInTransaction = true
        }
        return b
    }
    
    @discardableResult func beginExclusiveTransaction() throws -> Bool {
        let b = try executeUpdate("begin exclusive transaction")
        if (b) {
            _isInTransaction = true
        }
        return b
    }
    
    
    func inTransaction() -> Bool {
        _isInTransaction
    }

    func interrupt() -> Bool {
        if (_db != nil) {
            sqlite3_interrupt(_db);
            return true;
        }
        
        return false;
    }
    
    
    
    
    
    // Extras?
    
    func getTableSchema(_ name:String) throws -> FMResultSet {
        
        let s = "pragma table_info('\(name)')"
        
        return try executeQuery(s)
    }
    
    func boolForQuery(_ sqlStringAndBindings : Any...) throws -> Bool {
        
        let (sql, args) = pullSQLFromArgumnets(sqlStringAndBindings)
        
        let rs = try executeQuery(sql, argArray: args, argDictionary: nil, shouldBind: true)
        
        if (try !rs.next()) {
            return false
        }
        
        return rs.bool(0)
    }
    
    func intForQuery(_ sqlStringAndBindings : Any...) throws -> Int32 {
        
        let (sql, args) = pullSQLFromArgumnets(sqlStringAndBindings)
        
        let rs = try executeQuery(sql, argArray: args, argDictionary: nil, shouldBind: true)
        
        if (try !rs.next()) {
            return 0
        }
        
        return rs.int(0)
    }
     
    func dateForQuery(_ sqlStringAndBindings : Any...) throws -> NSDate? {
        
        let (sql, args) = pullSQLFromArgumnets(sqlStringAndBindings)
        
        let rs = try executeQuery(sql, argArray: args, argDictionary: nil, shouldBind: true)
        
        
        if (try !rs.next()) {
            return nil
        }
        
        return rs.date(0)
    }
     
    func changes() -> Int32 {
        
        if (_isExecutingStatement) {
            warnInUse()
            return 0;
        }
        
        
        _isExecutingStatement = true;
        
        let ret = sqlite3_changes(_db);
        
        _isExecutingStatement = false;
        
        return ret;
    }
    
    
    func validateSQL(_ sql : String) throws {
        
        var pStmt : OpaquePointer?
        let rc = sqlite3_prepare_v2(_db, sql, -1, &pStmt, nil)
        sqlite3_finalize(pStmt);
        
        if (rc != SQLITE_OK) {
            throw FMDBError.sqlite3ErrorCode(rc)
        }
        
    }
    
    func tableExists(_ tableName : String) -> Bool {
        
        do {
        
            let tableNameLower = tableName.lowercased()
            
            let rs = try self.executeQuery("select [sql] from sqlite_master where [type] = 'table' and lower(name) = ?", tableNameLower)
            
            let returnBool = try rs.next()
            
            rs.close()
            
            return returnBool
        }
        catch {
            return false
        }
        
    }
    
    func columnExists(_ columnName : String, inTable: String) -> Bool {
        
        do {
        
            let lowerTableName  = inTable.lowercased()
            let lowerColumnName = columnName.lowercased()
            
            var returnBool = false
            
            let rs = try self.getTableSchema(lowerTableName)
            
            while (try rs.next()) {
                
                if (rs.string("name")?.lowercased() == lowerColumnName) {
                    returnBool = true
                    break
                }
            }
            
            rs.close()
            
            return returnBool
        }
        catch {
            return false
        }
        
    }
    
    func getSchema() -> FMResultSet? {
        
        var rs : FMResultSet?
        
        do {
        
            rs = try executeQuery("SELECT type, name, tbl_name, rootpage, sql FROM (SELECT * FROM sqlite_master UNION ALL SELECT * FROM sqlite_temp_master) WHERE type != 'meta' AND name NOT LIKE 'sqlite_%' ORDER BY tbl_name, type DESC, name")
        }
        catch {
            
            print("getSchema has failed.")
        }
        
        return rs;
    }
    
    func setUserVersion(_ version: Int32) {
        
        
        var rs : FMResultSet?
        
        do {
        
            rs = try executeQuery("pragma user_version = \(version)")
            try rs?.next()
            rs?.close()
        }
        catch {
            print("setUserVersion has failed.")
        }
        
    }

    
    func userVersion() -> Int32 {
        
        var rs : FMResultSet
        
        do {
        
            rs = try executeQuery("pragma user_version")
            if (try rs.next()) {
                let r = rs.int(0)
                rs.close()
                return r;
            }
        }
        catch {
            print("userVersion has failed.")
        }
        
        return 0
    }
    
    func setApplicationID(_ appID:UInt32) {
        
        do {
            let rs = try executeQuery("pragma application_id=\(appID)")
            try rs.next()
            rs.close()
        }
        catch {
            print("setApplicationID has failed.")
        }
        
    }
    
    
    func applicationID() -> UInt32 {
        do {
            
            var r : UInt32 = 0
            
            let rs = try executeQuery("pragma application_id")
            if (try rs.next()) {
                r = UInt32(rs.longLongInt(0))
            }
            
            rs.close()
            
            return r
            
        }
        catch {
            print("applicationID has failed.")
        }
        
        return 0
    }
    
    func setApplicationIDString(_ appID : String) {
        
        if (appID.count != 4) {
            print("setApplicationIDString: string passed is not exactly 4 chars long. (was \(appID.count))");
        }
        
    
//            var r : FourCharCode = 0
//            for char in appID.utf16 {
//                r = (r << 8) + FourCharCode(char)
//            }
//
        
        let typeCode = NSHFSTypeCodeFromFileType("'\(appID)'")
        
        setApplicationID(typeCode)
        
    }
    
    func applicationIDString() -> String? {
        
        let s = NSFileTypeForHFSTypeCode(applicationID())
        
        if let s = s {
            
            if (s.count != 6) {
                return nil
            }
            
            let lowerBound = s.index(s.startIndex, offsetBy: 1)
            let upperBound = s.index(s.startIndex, offsetBy: 5)
            
            return String(s[lowerBound..<upperBound])
            
            //return NSString(string:s).substring(with: NSMakeRange(1, 4))
        }
        
        return nil
        
        
        
        
        
        
        
        
    }
    
    func warnInUse() {
        
        print("The FMDatabase \(self) is currently in use.");
            
        if (crashOnErrors) {
            assert(false, "The FMDatabase \(self) is currently in use.");
            abort();
        }
    }
    
    
}
