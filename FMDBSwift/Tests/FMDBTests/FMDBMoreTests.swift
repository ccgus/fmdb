import XCTest
import SQLite3
@testable import FMDB

final class FMDBMoreTests: FMDBTempDBTests {
    
    let tempPath = "/tmp/FMDBMoreTests.db"
    
    override func setUp() {
        
    }
    
    func testFunkyTableNames() throws {
        
        do {
            let db = emptyDatabase(path: tempPath)
            XCTAssert(try db.open())
            
            try db.executeUpdate("create table '234 fds' (foo text)")
            
            XCTAssertFalse(db.hadError(), "table creation should have succeeded")
            
            let rs = try db.getTableSchema("234 fds")
            XCTAssertTrue(try rs.next(), "Schema should have succeded");
            rs.close()
            
            XCTAssertFalse(db.hadError(), "There shouldn't be any errors")
            
        }
        
        catch {
            print(error)
            XCTAssert(false)
        }
    }
    
    
    
    
    func testBoolForQuery() throws {
        
        do {
            let db = emptyDatabase(path: tempPath)
            XCTAssert(try db.open())
            
            var result = try db.boolForQuery("SELECT ? not null", "")
            XCTAssertTrue(result, "Empty strings should be considered true");
            
            
            result = try db.boolForQuery("SELECT ? not null", NSMutableData())
            XCTAssertTrue(result, "Empty mutable data should be considered true");
            
            result = try db.boolForQuery("SELECT ? not null", NSData())
            XCTAssertTrue(result, "Empty data should be considered true");
        }
        
        catch {
            print(error)
            XCTAssert(false)
        }
    }
    
    func testIntForQuery() throws {
        
        do {
            let db = emptyDatabase(path: tempPath)
            XCTAssert(try db.open())
            
            try db.executeUpdate("create table t1 (a integer)")
            try db.executeUpdate("insert into t1 values (?)", 5)
            
            XCTAssertEqual(db.changes(), 1, "There should only be one change")
            
            let ia = try db.intForQuery("select a from t1 where a = ?", 5)
            XCTAssertEqual(ia, 5, "foo");
            
            
        }
        
        catch {
            print(error)
            XCTAssert(false)
        }
    }
    
    
    func testDateForQuery() throws {
        
        do {
            let db = emptyDatabase(path: tempPath)
            XCTAssert(try db.open())
            
            let date = NSDate()
            
            try db.executeUpdate("create table datetest (a double, b double, c double)")
            try db.executeUpdate("insert into datetest (a, b, c) values (?, ?, 0)", NSNull(), date)
            
            XCTAssertEqual(db.changes(), 1, "There should only be one change")
            
            let foo = try db.dateForQuery("select b from datetest where c = 0")
            
            let interval = foo!.timeIntervalSince(date as Date)
            
            XCTAssertEqual(interval, 0.0, accuracy: 1.0, "Dates should be the same to within a second");
            
            
        }
        
        catch {
            print(error)
            XCTAssert(false)
        }
    }
    
    func testValidate() throws {
        
        // This is just ported over from the other tests. It's kind of dumb, but whatever.
        do {
            let db = emptyDatabase(path: tempPath)
            XCTAssert(try db.open())
            try db.validateSQL("create table datetest (a double, b double, c double)")
            
            XCTAssertFalse(db.hadError())
            
            // XCTAssertNil(error, @"There should be no error object");
            
        }
        catch {
            print(error)
            XCTAssert(false)
        }
    }
    

    func testFailValidate() throws {
        
        var hadErr = false
        
        // This is just ported over from the other tests. It's kind of dumb, but whatever.
        do {
            let db = emptyDatabase(path: tempPath)
            XCTAssert(try db.open())
            
            try db.validateSQL("blah blah blah")
            
        }
        catch {
            print(error)
            hadErr = true
        }
        
        XCTAssertTrue(hadErr)
    }
    
    
    func testTableExists() throws {
        
        let db = emptyDatabase(path: tempPath)
        
        do {
            XCTAssert(try db.open())
            
            try db.executeUpdate("create table t4 (a text, b text)")
            
            XCTAssertTrue(db.tableExists("t4"));
            XCTAssertFalse(db.tableExists("thisdoesntexist"));
            
            let x = Optional("table")
            XCTAssertTrue(x == "table")
            
            let rs = db.getSchema()
            if let rs = rs {
                while (try rs.next()) {
                    print("\(String(describing: rs.string("type")))")
                    XCTAssertTrue(rs.string("type") == "table");
                }
            }
            
            
        }
        catch {
            print(error)
            print("\(String(describing: db.lastErrorMessage()))")
            XCTAssertTrue(false)
        }
        
    }
    
    
    func testColumnExists() throws {
        
        let db = emptyDatabase(path: tempPath)
        
        do {
            XCTAssert(try db.open())
            
            try db.executeUpdate("create table nulltest (a text, b text)")
            
            XCTAssertTrue(db.columnExists("a", inTable: "nulltest"))
            XCTAssertTrue(db.columnExists("b", inTable: "nulltest"))
            XCTAssertFalse(db.columnExists("c", inTable: "nulltest"))
            
            
            
        }
        catch {
            print(error)
            print("\(String(describing: db.lastErrorMessage()))")
            XCTAssertTrue(false)
        }
        
    }
    
    func testUserVersion() throws {
        
        let db = emptyDatabase(path: tempPath)
        
        XCTAssert(try db.open())
        
        db.setUserVersion(10)
        
        XCTAssertTrue(db.userVersion() == 10);
     
    }
    
    func fourCharCode(from string : String) -> FourCharCode
    {
      return string.utf16.reduce(0, {$0 << 8 + FourCharCode($1)})
    }
    
    func testApplicationID() throws {
        
        let appID = NSHFSTypeCodeFromFileType(NSFileTypeForHFSTypeCode(fourCharCode(from: "fmdb")))
        
        let db = emptyDatabase(path: tempPath)
        
        XCTAssert(try db.open())
        
        db.setApplicationID(appID)
        
        let rAppID = db.applicationID()
        
        XCTAssertEqual(rAppID, appID);
        
        db.setApplicationIDString("acrn")
        
        let s = db.applicationIDString()
        
        XCTAssertEqual(s, "acrn")
        
    }
    
    func testFailOnUnopenedDatabase() throws {
        
        let db = emptyDatabase(path: tempPath)
        
        XCTAssert(try db.open())
        
        db.close()
        
        var hadError = false
        
        do {
            let rs = try db.executeQuery("select * from table")
            XCTAssertNil(rs, "Shouldn't get results from an empty table")
        }
        catch {
            hadError = true
        }
        XCTAssertTrue(hadError)
        XCTAssertTrue(db.hadError())

    }
    
    
    func testFailOnBadStatement() throws {
        
        let db = emptyDatabase(path: tempPath)
        
        XCTAssert(try db.open())
        
        var hadError = false
        
        do {
            let rs = try db.executeQuery("blah blah blah")
            XCTAssertNil(rs, "Shouldn't get results from an empty table")
        }
        catch {
            hadError = true
        }
        XCTAssertTrue(hadError)
        XCTAssertTrue(db.hadError())

    }
    
    
    func testSelectULL() throws {
        
        let db = emptyDatabase(path: tempPath)
        
        XCTAssert(try db.open())
        
        do {

            try db.executeUpdate("create table ull (a integer)")
            try db.executeUpdate("insert into ull (a) values (?)", CUnsignedLongLong.max);
            
            let rs = try db.executeQuery("select a from ull")
            while (try rs.next()) {
                XCTAssertEqual(rs.unsignedLongLongInt(0), UInt64.max, "Result should be \(CUnsignedLongLong.max)")
                XCTAssertEqual(rs.unsignedLongLongInt("a"), UInt64.max, "Result should be \(CUnsignedLongLong.max)")
            }
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    
    
    
    func testSelectByColumnName() throws {
        
        let db = populatedOpenDatabase(path: tempPath)
        
        do {


            let rs = try db.executeQuery("select rowid,* from test where a = ?", "hi")
            
            XCTAssertNotNil(rs, "Should have a non-nil result set");
            
            while (try rs.next()) {
                XCTAssertTrue(rs.int("c") > 0)
                
                
                XCTAssertNotNil(rs.string("b"), "Should have non-nil string for 'b'");
                XCTAssertNotNil(rs["b"], "Should have non-nil string for 'b' subscript");
                XCTAssertNotNil(rs.string("a"), "Should have non-nil string for 'a'");
                XCTAssertNotNil(rs.string("rowid"), "Should have non-nil string for 'rowid'");
                XCTAssertNotNil(rs.string("d"), "Should have non-nil date for 'd'");
                
                
                XCTAssertTrue(rs.double("d") > 0)
                XCTAssertTrue(rs.double("e") > 0)
                XCTAssertTrue(type(of: rs["b"]) == type(of: ""))
                XCTAssertTrue(type(of: rs["e"]) == type(of: 2.2))
                
                
                XCTAssertTrue(rs.columnNameForIndex(0) == "rowid", "Wrong column name for result set column number")
                XCTAssertTrue(rs.columnNameForIndex(1) == "a",     "Wrong column name for result set column number")
            }
            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    
    func testInvalidColumnNames() throws {
        
        let db = populatedOpenDatabase(path: tempPath)
        
        do {


            let rs = try db.executeQuery("select rowid, a, b, c from test")
            
            XCTAssertNotNil(rs, "Should have a non-nil result set");
            
            let invalidColumnName = "foobar"
            
            while (try rs.next()) {
                
                XCTAssertNil(rs[invalidColumnName], "Invalid column name should return nil")
                XCTAssertNil(rs.string(invalidColumnName), "Invalid column name should return nil")
                XCTAssertEqual(rs.UTF8String(invalidColumnName), nil, "Invalid column name should return nil")
                XCTAssertNil(rs.date(invalidColumnName), "Invalid column name should return nil")
                XCTAssertNil(rs.data(invalidColumnName), "Invalid column name should return nil")
                XCTAssertNil(rs.dataNoCopy(invalidColumnName), "Invalid column name should return nil")
                
            }
            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    
    func testInvalidColumnIndexes() throws {
        
        let db = populatedOpenDatabase(path: tempPath)
        
        do {


            let rs = try db.executeQuery("select rowid, a, b, c from test")
            
            XCTAssertNotNil(rs, "Should have a non-nil result set");
            
            let invalidColumnIndex = Int32(999)
            
            while (try rs.next()) {
                
                XCTAssertNil(rs[invalidColumnIndex], "Invalid column name should return nil")
                XCTAssertNil(rs.string(invalidColumnIndex), "Invalid column name should return nil")
                XCTAssertEqual(rs.UTF8String(invalidColumnIndex), nil, "Invalid column name should return nil")
                XCTAssertNil(rs.date(invalidColumnIndex), "Invalid column name should return nil")
                XCTAssertNil(rs.data(invalidColumnIndex), "Invalid column name should return nil")
                XCTAssertNil(rs.dataNoCopy(invalidColumnIndex), "Invalid column name should return nil")
                
            }
            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    
    func testBusyRetryTimeout() throws {
        
        let db = populatedOpenDatabase(path: tempPath)
        
        do {


            try db.executeUpdate("create table t1 (a integer)")
            try db.executeUpdate("insert into t1 values (?)", 5)
            
            db.setMaxBusyRetryTimeInterval(2)
            
            let newDB = FMDatabase.database(with: tempPath)
            try newDB.open()
            
            let rs = try newDB.executeQuery("select rowid,* from test where a = ?", "hi'")
            try rs.next() // just grab one... which will keep the db locked
            
            XCTAssertFalse(try db.executeUpdate("insert into t1 values (5)"), "Insert should fail because the db is locked by a read")
            
            XCTAssertEqual(db.lastErrorCode(), SQLITE_BUSY, "SQLITE_BUSY should be the last error");
            
            rs.close()
            newDB.close()
            
            XCTAssertTrue(try db.executeUpdate("insert into t1 values (5)"), "The database shouldn't be locked at this point")
            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    func testCaseSensitiveResultDictionary() throws {
        
        let db = populatedOpenDatabase(path: tempPath)
        
        do {

            
            // case sensitive result dictionary test
            try db.executeUpdate("create table cs (aRowName integer, bRowName text)")
            try db.executeUpdate("insert into cs (aRowName, bRowName) values (?, ?)", 1, "hello")
            
            XCTAssertFalse(db.hadError(), "Shouldn't have any errors")
            
            let rs = try db.executeQuery("select * from cs")
            while (try rs.next()) {
                
                let d = rs.resultDictionary()
                
                print("dict is: \(d)")
                
                let t = type(of:d["aRowName"])
                
                print("the type is : \(t)")
                
                XCTAssertNotNil(d["aRowName"], "aRowName should be non-nil");
                XCTAssertNil(d["arowname"], "arowname should be nil");
                XCTAssertNotNil(d["bRowName"], "bRowName should be non-nil");
                XCTAssertNil(d["browname"], "browname should be nil");
                
            }
            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
            
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    
    func testBoolInsert() throws {
        
        let db = populatedOpenDatabase(path: tempPath)
        
        do {

            
            // case sensitive result dictionary test
            try db.executeUpdate("create table btest (aRowName integer)")
            try db.executeUpdate("insert into btest (aRowName) values (?)", true)
            
            XCTAssertFalse(db.hadError(), "Shouldn't have any errors")
            
            let rs = try db.executeQuery("select * from btest")
            while (try rs.next()) {
                XCTAssertTrue(rs.bool(0), "first column should be true.");
                XCTAssertTrue(rs.int(0) == 1, "first column should be equal to 1 - it was \(rs.int(0)).");

            }
            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
            
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    
    func testNamedParametersCount() throws {
        
        let db = populatedOpenDatabase(path: tempPath)
        
        do {

            XCTAssertTrue(try db.executeUpdate("create table namedparamcounttest (a text, b text, c integer, d double)"))
            
            var dictionaryArgs = [String: Any]()
            
            dictionaryArgs["a"] = "Text1"
            dictionaryArgs["b"] = "Text2"
            dictionaryArgs["c"] = 1
            dictionaryArgs["d"] = 2.0
            
            XCTAssertTrue(try db.executeUpdate("insert into namedparamcounttest values (:a, :b, :c, :d)", withParameterDictionary: dictionaryArgs))
            
            var rs = try db.executeQuery("select * from namedparamcounttest")
            
            XCTAssertNotNil(rs);
            
            XCTAssertTrue(try rs.next())
            
            XCTAssertTrue(rs.string("a") == "Text1")
            XCTAssertTrue(rs.string("b") == "Text2")
            XCTAssertTrue(rs.int("c") == 1)
            XCTAssertTrue(rs.double("d") == 2.0)
            
            rs.close()
            
            
            // note that at this point, dictionaryArgs has way more values than we need, but the query should still work since
            // a is in there, and that's all we need.
            rs = try db.executeQuery("select * from namedparamcounttest where a = :a", withParameterDictionary:dictionaryArgs)
            
            XCTAssertNotNil(rs);
            
            XCTAssertTrue(try rs.next())
            
            rs.close()
            
             // ***** Please note the following codes *****
             
            dictionaryArgs = [String: Any]()
            
            dictionaryArgs["a"] = "NewText1"
            dictionaryArgs["b"] = "NewText2"
            dictionaryArgs["OneMore"] = "OneMoreText"
            
            XCTAssertTrue(try db.executeUpdate("update namedparamcounttest set a = :a, b = :b where b = 'Text2'", withParameterDictionary:dictionaryArgs))
            
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    
    
    func testBlobs() throws {
        
        let db = populatedOpenDatabase(path: tempPath)
        
        do {
            
            try db.executeUpdate("create table blobTable (a text, b blob)")
            
            let binSHBinary = try Data(contentsOf: URL(fileURLWithPath: "/bin/sh"))
            
            try db.executeUpdate("insert into blobTable (a, b) values (?, ?)", "bin/sh", binSHBinary)
            
            let rs = try db.executeQuery("select b from blobTable where a = ?", "bin/sh")
            XCTAssertTrue(try rs.next());
            let readData = rs.data("b")
            
            XCTAssertTrue(readData == binSHBinary)
            
            
            let readDataNoCopy = rs.dataNoCopy("b");
            XCTAssertTrue(readDataNoCopy == binSHBinary)
            
            rs.close()
            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
            
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    func testNullValues() throws {
        
        let db = populatedOpenDatabase(path: tempPath)
        
        do {
            
            try db.executeUpdate("create table t2 (a integer, b integer)")
            
            let rc = try db.executeUpdate("insert into t2 values (?, ?)", NSNull(), 5)
            XCTAssertTrue(rc, "Failed to insert a nil value");
            
            
            let rs = try db.executeQuery("select * from t2")
            while (try rs.next()) {
                XCTAssertNil(rs.string(0), "Wasn't able to retrieve a null string");
                XCTAssert(rs.string(1) == "5")
            }
            
            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
            
            
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    
    func testNestedResultSets() throws {
        
        let db = populatedOpenDatabase(path: tempPath)
        
        do {
            
            let rs = try db.executeQuery("select * from t3")
            while (try rs.next()) {
                let foo = rs.int(0)
                let newValue = foo + 11
                try db.executeUpdate("update t3 set a = ? where a = ?", newValue, foo)
                
                let rs2 = try db.executeQuery("select a from t3 where a = ?", newValue)
                try rs2.next()
                
                XCTAssertTrue(rs2.int(0) == newValue)
                rs2.close()
            }
            
            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
            
            
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    func testNSNullInsertion() throws {
        
        let db = populatedOpenDatabase(path: tempPath)
        
        do {
            
            try db.executeUpdate("create table nulltest (a text, b text)")
            try db.executeUpdate("insert into nulltest (a, b) values (?, ?)", NSNull(), "a")
            try db.executeUpdate("insert into nulltest (a, b) values (?, ?)", nil, "b")
            
            
            
            let rs = try db.executeQuery("select * from nulltest")
            while (try rs.next()) {
                
                XCTAssertNil(rs.string(0));
                XCTAssertNotNil(rs.string(1));
            }
            
            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
            
            
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    
    
    func testNSNullDates() throws {
        
        let date = Date()
        
        let db = populatedOpenDatabase(path: tempPath)
        
        do {
            
            try db.executeUpdate("create table datetest (a double, b double, c double)")
            try db.executeUpdate("insert into datetest (a, b, c) values (?, ?, 0)", nil, date)
            
            
            let rs = try db.executeQuery("select * from datetest")
            while (try rs.next()) {
                
                let b = rs.date(1)
                let c = rs.date(2)
                
                XCTAssertNil(rs.date(0));
                XCTAssertNotNil(c, "zero date shouldn't be nil");
                
                XCTAssertEqual(b!.timeIntervalSince(date),  0.0, accuracy: 1.0, "Dates should be the same to within a second");
                XCTAssertEqual(c!.timeIntervalSince1970  ,  0.0, accuracy: 1.0, "Dates should be the same to within a second");
            }
            
            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
            
            
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    
    
    
    func testLotsOfNULLs() throws {
        
        
        let db = populatedOpenDatabase(path: tempPath)
        
        do {
            
            let binSHBinary = try Data(contentsOf: URL(fileURLWithPath: "/bin/sh"))
            
            try db.executeUpdate("create table nulltest2 (s text, d data, i integer, f double, b integer)")
            try db.executeUpdate("insert into nulltest2 (s, d, i, f, b) values (?, ?, ?, ?, ?)", "hi", binSHBinary, 12, 4.4, true)
            try db.executeUpdate("insert into nulltest2 (s, d, i, f, b) values (?, ?, ?, ?, ?)" , nil, nil, nil, nil, NSNull());
            
            
            let rs = try db.executeQuery("select * from nulltest2")
            while (try rs.next()) {
                
                let i = rs.int(2)
                
                if (i == 12) {
                    
                    // it's the first row we inserted.
                    
                    XCTAssertFalse(rs.columnIsNull(0))
                    XCTAssertFalse(rs.columnIsNull(1))
                    XCTAssertFalse(rs.columnIsNull(2))
                    XCTAssertFalse(rs.columnIsNull(3))
                    XCTAssertFalse(rs.columnIsNull(4))
                    XCTAssertTrue(rs.columnIsNull(5))
                    
                    
                    XCTAssertTrue(rs.data("d") == binSHBinary)
                    XCTAssertNil(rs.data("notthere"))
                    XCTAssertNil(rs.string(-2), "Negative columns should return nil results")
                    XCTAssertTrue(rs.bool(4))
                    XCTAssertTrue(rs.bool("b"))
                    
                    XCTAssertEqual(4.4, rs.double("f"), accuracy: 0.0000001, "Saving a float and returning it as a double shouldn't change the result much");
                    
                    XCTAssertEqual(rs.int("i"), 12)
                    XCTAssertEqual(rs.int(2), 12)
                    
                    XCTAssertEqual(rs.int(12), 0, "Non-existent columns should return zero for ints")
                    XCTAssertEqual(rs.int("not there"), 0, "Non-existent columns should return zero for ints")
                    
                    XCTAssertEqual(rs.longLongInt("i"), 12)
                    XCTAssertEqual(rs.longLongInt(2), 12)
                    
                }
                else {
                    
                    XCTAssertTrue(rs.columnIsNull(0))
                    XCTAssertTrue(rs.columnIsNull(1))
                    XCTAssertTrue(rs.columnIsNull(2))
                    XCTAssertTrue(rs.columnIsNull(3))
                    XCTAssertTrue(rs.columnIsNull(4))
                    XCTAssertTrue(rs.columnIsNull(5))
                    
                    XCTAssertNil(rs.data("d"))
                }
            }
            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    
    func testUTF8Strings() throws {
        
        let db = populatedOpenDatabase(path: tempPath)
        
        do {
            
            try db.executeUpdate("create table utest (a text)")
            try db.executeUpdate("insert into utest values (?)", "/übertest")
            
            
            let rs = try db.executeQuery("select * from utest where a = ?", "/übertest")
           
            XCTAssertTrue(try rs.next());
            rs.close();

            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
            
            
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    
    func testArgumentsInArray() throws {
        
        let db = emptyDatabase(path: tempPath)
        
        do {
            
            try db.open()
            
            try db.executeUpdate("create table testOneHundredTwelvePointTwo (a text, b integer)")
            try db.executeUpdate("insert into testOneHundredTwelvePointTwo values (?, ?)", ["one", 2])
            try db.executeUpdate("insert into testOneHundredTwelvePointTwo values (?, ?)", ["one", 3])
            
            
            let rs = try db.executeQuery("select * from testOneHundredTwelvePointTwo where b > ?", [1])
           
            XCTAssertTrue(try rs.next());
            
            XCTAssertTrue(rs.hasAnotherRow())
            XCTAssertFalse(db.hadError())
            
            XCTAssertTrue(rs.string(0) == "one")
            XCTAssertEqual(rs.int(1), 2)
            
            XCTAssertTrue(try rs.next())
            
            XCTAssertEqual(rs.int(1), 3)
            
            XCTAssertFalse(try rs.next())
            XCTAssertFalse(rs.hasAnotherRow())
            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
            
            
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
    
    func testColumnNamesContainingPeriods() throws {
        
        let db = emptyDatabase(path: tempPath)
        
        do {
            
            try db.open()
            
            try db.executeUpdate("create table t4 (a text, b text)")
            try db.executeUpdate("insert into t4 (a, b) values (?, ?)", "one", "two")
            
            
            var rs = try db.executeQuery("select t4.a as 't4.a', t4.b from t4")
           
            XCTAssertTrue(try rs.next())
            
            XCTAssertTrue(rs.string("t4.a") == "one")
            XCTAssertTrue(rs.string("b") ==  "two")
            
            //XCTAssertEqual(strcmp((const char*)[rs UTF8StringForColumn:@"b"], "two"), 0, @"String comparison should return zero");
            
            rs.close()
            
            XCTAssertTrue(try db.executeUpdate("drop table t4", []))
            XCTAssertTrue(try db.executeUpdate("create table t4 (a text, b text)", []))
            
            try db.executeUpdate("insert into t4 (a, b) values (?, ?)", ["one", "two"])
            
            rs = try db.executeQuery("select t4.a as 't4.a', t4.b from t4", [])
            
             XCTAssertTrue(try rs.next())
            
            XCTAssertTrue(rs.string("t4.a") == "one")
            XCTAssertTrue(rs.string("b") ==  "two")
            
            rs.close()
            
            XCTAssertFalse(db.hasOpenResultSets())
            XCTAssertFalse(db.hadError())
        }
        catch {
            print(error)
            XCTAssertTrue(false)
        }
    }
    
}
