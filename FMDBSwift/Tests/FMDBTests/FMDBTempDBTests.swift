import XCTest
@testable import FMDB

class FMDBTempDBTests: XCTestCase {
//    
//    var db : FMDatabase
//    var databasePath : String?
//    
//    
//    let testDatabasePath = "/tmp/tmp.db"
//    static let populatedDatabasePath = "/tmp/tmp-populated.db"
//    
//    
//    public override init(selector: Selector) {
//        self.db = FMDatabase()
//        super.init(selector: selector)
//    }
//    
//    override static func setUp() {
//        
//        
//        super.setUp()
//        
//        let url = NSURL(fileURLWithPath: populatedDatabasePath, isDirectory: false)
//        
//        let fileManager = FileManager()
//        try? fileManager.removeItem(at: url as URL)
//        
//        
//        /*
//        // Delete old populated database
//        NSFileManager *fileManager = [NSFileManager defaultManager];
//        [fileManager removeItemAtPath:populatedDatabasePath error:NULL];
//        
//        if ([self respondsToSelector:@selector(populateDatabase:)]) {
//            FMDatabase *db = [FMDatabase databaseWithPath:populatedDatabasePath];
//            
//            [db open];
//            [self populateDatabase:db];
//            [db close];
//        }*/
//        
//        
//    }
    
    public func emptyDatabase(path: String) -> FMDatabase {
        let url = URL(fileURLWithPath: path, isDirectory: false)

        let fileManager = FileManager()
        try? fileManager.removeItem(at: url as URL)
        
        let db = FMDatabase.database(with: url)
        
        return db
        
    }

    public func populatedOpenDatabase(path: String) -> FMDatabase {
        let url = URL(fileURLWithPath: path, isDirectory: false)

        let fileManager = FileManager()
        try? fileManager.removeItem(at: url as URL)
        
        let db = FMDatabase.database(with: url)
        
        
        do {
            
            try db.open()
            
            try db.executeUpdate("create table test (a text, b text, c integer, d double, e double)")
            
            try db.beginTransaction()
            
            var i = 0
            while (i < 20) {
                i = i + 1
                
                try db.executeUpdate("insert into test (a, b, c, d, e) values (?, ?, ?, ?, ?)", "hi'", "number \(i)", i, NSDate(), 2.2)
                
                try db.executeUpdate("insert into test (a, b, c, d, e) values (?, ?, ?, ?, ?)", "hi again'", "number \(i)", i, NSDate(), 2.2)
                
            }
            try db.commit()
            
            
            try db.executeUpdate("create table t3 (a somevalue)")
            
            try db.beginTransaction()
            
            i = 0
            while (i < 20) {
                i = i + 1
                
                try db.executeUpdate("insert into t3 (a) values (?)", i)
            }
            try db.commit()
        }
        catch {
            assert(false, "\(error)")
        }
        
        
        
        
        
        
        
        
        
        
        return db
        
    }

    
    
    
    
    
    
    
}
