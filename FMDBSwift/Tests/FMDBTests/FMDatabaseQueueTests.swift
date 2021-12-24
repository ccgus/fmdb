import XCTest
import SQLite3
@testable import FMDB

final class FMDatabaseQueueTests: FMDBTempDBTests {
    
    let tempPath = "/tmp/FMDatabaseQueueTests.db"
    
    override func setUp() {
        
    }
    
    /*
    func testURLOpenNoPath() throws {
        
        do {
            let q = FMDatabaseQueue()
            XCTAssert(q != nil, "Database queue should be returned")
        }
        
        catch {
            print(error)
            XCTAssert(false)
        }
    }*/
    
    func testSimpleSelect() throws {
        
        let q = FMDatabaseQueue.queue(with: tempPath)
        
        var worked = false
        
        q.inDatabase({ db in
            
            do {
                let rs = try db.executeQuery("select 'hello'")
                try rs.next()
                
                XCTAssertTrue(rs.string(0) == "hello")
                rs.close()
                worked = true
            }
            
            catch {
                print(error)
                XCTAssert(false)
            }
            
        })
        
        XCTAssert(worked)
    }
    
    
    
    
}
