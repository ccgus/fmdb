import XCTest
import SQLite3
@testable import FMDB

final class FMDBTests: FMDBTempDBTests {
    
    let tempPath = "/tmp/FMDBTests.db"
    
    override func setUp() {
        
    }
    
    func testExample() throws {
        do {
            
            NSLog("Is SQLite compiled with it's thread safe options turned on? %@!", FMDatabase.isSQLiteThreadSafe() ? "Yes" : "No");
            let db = emptyDatabase(path: tempPath)
            
            XCTAssert(try db.open())
            
            let rs = try db.executeQuery("select 'hi'")
            XCTAssert(try rs.next())
            print(rs.string(0) as Any)
            XCTAssert(rs.string(0) == "hi")
            
            XCTAssert(db.close())
        }
        catch {
            print(error)
            XCTAssert(false)
        }
        //_ = db.executeUpdate(statement: "create table test (a text, b text, c integer, d double, e double)");
        
    }
    
    func testNextWithError_WithoutError() throws
    {
        
        do {
            let db = emptyDatabase(path: tempPath)
            
            XCTAssert(try db.open())
            
            try db.executeUpdate("CREATE TABLE testTable(key INTEGER PRIMARY KEY, value INTEGER)")
            try db.executeUpdate("INSERT INTO testTable (key, value) VALUES (1, 2)")
            try db.executeUpdate("INSERT INTO testTable (key, value) VALUES (2, 4)")
            
            let resultSet = try db.executeQuery("SELECT * FROM testTable WHERE key=1")
            XCTAssertNotNil(resultSet)
            
            XCTAssertTrue(try resultSet.next())
            XCTAssertFalse(try resultSet.next())
            
            resultSet.close()
            
        }
        catch {
            print(error)
            XCTAssert(false)
        }
    }
    
    func testNextWithError_WithBusyError() throws
    {
        do {
            let db = emptyDatabase(path: tempPath)
            
            XCTAssert(try db.open())
            
            try db.executeUpdate("CREATE TABLE testTable(key INTEGER PRIMARY KEY, value INTEGER)")
            try db.executeUpdate("INSERT INTO testTable (key, value) VALUES (1, 2)")
            try db.executeUpdate("INSERT INTO testTable (key, value) VALUES (2, 4)")
            
            let resultSet = try db.executeQuery("SELECT * FROM testTable WHERE key=1")
            XCTAssertNotNil(resultSet)
            
            
            let newDB = FMDatabase.database(with: tempPath)
            XCTAssert(try newDB.open())
            
            try newDB.beginExclusiveTransaction()
            
            var caught = false
            
            do {
                let b = try resultSet.next()
                XCTAssertFalse(b) // we never actually get here :/
            }
            catch FMDBError.sqlite3ErrorCode(let sqlite3Code) {
                caught = true
                XCTAssertEqual(sqlite3Code, SQLITE_BUSY, "SQLITE_BUSY should be the last error")
            }
            
            XCTAssertTrue(caught)
            
            try newDB.commit()
            resultSet.close()
            
        }
        catch {
            print(error)
            XCTAssert(false)
        }
    }
    
    
    
    func testNextWithError_WithMisuseError() throws
    {
        do {
            let db = emptyDatabase(path: tempPath)
            
            XCTAssert(try db.open())
            
            try db.executeUpdate("CREATE TABLE testTable(key INTEGER PRIMARY KEY, value INTEGER)")
            try db.executeUpdate("INSERT INTO testTable (key, value) VALUES (1, 2)")
            try db.executeUpdate("INSERT INTO testTable (key, value) VALUES (2, 4)")
            
            
            let resultSet = try db.executeQuery("SELECT * FROM testTable WHERE key=9")
            XCTAssertNotNil(resultSet)
            XCTAssertFalse(try resultSet.next())
            
            
            var caught = false
            
            do {
                try resultSet.next()
            }
            catch FMDBError.sqlite3ErrorCode(let sqlite3Code) {
                caught = true
                XCTAssertEqual(sqlite3Code, SQLITE_MISUSE, "SQLITE_MISUSE should be the last error")
            }
            
            XCTAssertTrue(caught)
        }
        catch {
            print(error)
            XCTAssert(false)
        }
    }
    
    
    func testColumnTypes() throws
    {
        do {
            let db = emptyDatabase(path: tempPath)
            XCTAssert(try db.open())
            
            try db.executeUpdate("CREATE TABLE testTable (intValue INTEGER, floatValue FLOAT, textValue TEXT, blobValue BLOB)")
            
            let sql = "INSERT INTO testTable (intValue, floatValue, textValue, blobValue) VALUES (?, ?, ?, ?)";
            
            let data = NSString("foo").data(using: String.Encoding.utf8.rawValue)
            let zeroLengthData = NSData()
            let n = NSNull()
            
            try db.executeUpdate(sql, 42, Double.pi, "test", data as Any)
            try db.executeUpdate(sql, n, n, n, n)
            try db.executeUpdate(sql, n, n, n, zeroLengthData)
            
            
            let resultSet = try db.executeQuery("SELECT * FROM testTable order by rowid")
            XCTAssertNotNil(resultSet)
            
            
            // Weird but true. If we grab the value of the blob as a string (using resultSet.stringFor(columnIndex: 3)) before
            // grabbing it as a blob (or using it as resultSet.typeForColumn("blobValue")), then it's type will be cached in
            // sqlite somewhere as SQLITE_TEXT. So, in this order:
            // resultSet.typeForColumnIndex(3) // 4
            // resultSet.stringFor(columnIndex: 3) // "foo"
            // resultSet.typeForColumnIndex(3) // 3
            // That's kind of odd.
            
            
            XCTAssertTrue(try resultSet.next())
            XCTAssertEqual(resultSet.typeForColumn("intValue"), SqliteValueType.SqliteValueTypeInteger.rawValue)
            XCTAssertEqual(resultSet.typeForColumn("floatValue"), SqliteValueType.SqliteValueTypeFloat.rawValue)
            XCTAssertEqual(resultSet.typeForColumn("textValue"), SqliteValueType.SqliteValueTypeText.rawValue)
            XCTAssertEqual(resultSet.typeForColumn("blobValue"), SqliteValueType.SqliteValueTypeBlob.rawValue)
            XCTAssertNotNil(resultSet.data("blobValue"))
            
            XCTAssertTrue(try resultSet.next())
            XCTAssertEqual(resultSet.typeForColumn("intValue"), SqliteValueType.SqliteValueTypeNull.rawValue)
            XCTAssertEqual(resultSet.typeForColumn("floatValue"), SqliteValueType.SqliteValueTypeNull.rawValue)
            XCTAssertEqual(resultSet.typeForColumn("textValue"), SqliteValueType.SqliteValueTypeNull.rawValue)
            XCTAssertEqual(resultSet.typeForColumn("blobValue"), SqliteValueType.SqliteValueTypeNull.rawValue)
            XCTAssertNil(resultSet.data("blobValue"))
            
            XCTAssertTrue(try resultSet.next())
            XCTAssertEqual(resultSet.typeForColumn("blobValue"), SqliteValueType.SqliteValueTypeBlob.rawValue)
            XCTAssertNil(resultSet.data("blobValue"))
        }
        catch {
            print(error)
            XCTAssert(false)
        }
    }
    
    func testURLOpen() throws {

        let tempFolder = NSURL.init(fileURLWithPath: NSTemporaryDirectory())
        let fileURL = tempFolder.appendingPathComponent(NSUUID().uuidString)
        let fileManager = FileManager()
        try? fileManager.removeItem(at: fileURL! as URL)
        
        let db = FMDatabase.database(with: fileURL!)
        
        XCTAssert(try db.open(), "Open should succeed")
        
        XCTAssertTrue(((db.databaseURL()?.isEqual(to: fileURL)) != nil), "URLs should be the same");
        
        XCTAssert(db.close(), "Close should succeed")
        
    }
    
    
    
    
}
