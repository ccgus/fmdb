
import Foundation
import SQLite3

public class FMStatement : NSObject {
    
    public var _statement : OpaquePointer? = nil
    public var _query : String?
    public var useCount : Int64  = 0
    public var _inUse : Bool = false
    
    public override init() {
        
    }
    
    deinit {
        self.close()
    }
    
    
    public func close() {
        
        if (_statement != nil) {
            sqlite3_finalize(_statement);
            _statement = nil;
        }
        
        _inUse = false;
    }
    
    public func reset() {
        
        if (_statement != nil) {
            sqlite3_reset(_statement);
        }
        
        _inUse = false;
    }
    
}
