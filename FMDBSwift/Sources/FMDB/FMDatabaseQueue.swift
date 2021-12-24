import Foundation
import SQLite3

public class FMDatabaseQueue : NSObject {
    
    
    enum FMDBTransaction : Int32 {
        case FMDBTransactionExclusive = 1,
             FMDBTransactionDeferred  = 2,
             FMDBTransactionImmediate = 3
    }
    
    
    
    var _databasePath : String?
    var _openFlags : Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE
    var _vfsName : String?
    private var _db : FMDatabase?
    
    static var savePointIdx : CUnsignedLong = 0
    
    public let queue = DispatchQueue(label: "fmdb.\(String(describing: self))")
    
    private let queueKey = DispatchSpecificKey<FMDatabaseQueue>()
    
    public override init() {
        super.init()
        
        queue.setSpecific(key:queueKey, value:self)
        
        print(queue)
    }
    
    deinit {
        
        if let _db = _db {
            queue.sync {
                if (!_db.close()) {
                    print("Could not close database")
                }
            }
        }
        
        
    }
    
    public func interrupt() {
        _db?.interrupt()
    }
    
    // FIXME: What would the swift version of this be?
    /*
     + (Class)databaseClass {
         return [FMDatabase class];
     }
     */
    
    
    
    
    
    
    static func queue(with filePath : String) -> FMDatabaseQueue {
        
        let q = FMDatabaseQueue()
        
        q._databasePath = filePath
        
        return q
    }
    
    static func queue(with fileURL : URL) -> FMDatabaseQueue {
        return FMDatabaseQueue.queue(with: fileURL.path)
    }
    
    func database() -> FMDatabase? {
        
        if (_db == nil || !(_db!._isOpen)) {
            
            if (_db == nil) {
                
                _db = FMDatabase.database(with: _databasePath!)
                
            }
            
            do {
                try _db?.openWithFlags(flags: _openFlags, vfsName: _vfsName)
            }
            catch {
                print(error)
                abort()
            }
        }
        
        return _db
        
    }
    
    func inDatabase(_ f: (FMDatabase) -> ()) {
      
        /* Get the currently executing queue (which should probably be nil, but in theory could be another DB queue
         * and then check it against self to make sure we're not about to deadlock. */
        
        let currentSyncQueue = queue.getSpecific(key: queueKey)
        assert(currentSyncQueue != self, "inDatabase: was called reentrantly on the same queue, which would lead to a deadlock")

        
        queue.sync {
            
            let db = database()
            
            f(db!)
            
            
            if (db!.hasOpenResultSets()) {
                print("Warning: there is at least one open result set around after performing FMDatabaseQueue.inDatabase()")
            }
        }
    }
    
    
    func beginTransaction(transaction: FMDBTransaction, f: (FMDatabase, inout Bool) -> ()) {
        
        
        queue.sync {
            
            if let db = database() {
                
                var shouldRollback = false
                
                do {
                    
                    switch (transaction) {
                        
                    case .FMDBTransactionExclusive:
                        try db.beginExclusiveTransaction()
                        break
                             
                    case .FMDBTransactionDeferred:
                        try db.beginDeferredTransaction()
                        break
                        
                    case .FMDBTransactionImmediate:
                        try db.beginImmediateTransaction()
                        break
                        
                    }
                    
                    f(db, &shouldRollback)
                    
                    if (shouldRollback) {
                        try db.rollback();
                    }
                    else {
                        try db.commit();
                    }
                }
                catch {
                    print(error)
                }
            }
        }
        
    }
    
    
    func inTransaction(_ f: (FMDatabase, inout Bool) -> ()) {
        beginTransaction(transaction: .FMDBTransactionExclusive, f: f)
    }
    
    func inDeferredTransaction(_ f: (FMDatabase, inout Bool) -> ()) {
        beginTransaction(transaction: .FMDBTransactionDeferred, f: f)
    }
    
    func inExclusiveTransaction(_ f: (FMDatabase, inout Bool) -> ()) {
        beginTransaction(transaction: .FMDBTransactionExclusive, f: f)
    }
    
    func inImmediateTransaction(_ f: (FMDatabase, inout Bool) -> ()) {
        beginTransaction(transaction: .FMDBTransactionImmediate, f: f)
    }
    
    
    func inSavePoint(_ f: (FMDatabase, inout Bool) -> ()) {
        
        
        queue.sync {
            
            #warning("Need to implement startSavePointWithName in FMDatabase before the Queue can do inSavePoint:")
            FMDatabaseQueue.savePointIdx = FMDatabaseQueue.savePointIdx + 1
            
//            let name = "savePoint\(FMDatabaseQueue.savePointIdx)"
//            var shouldRollback = false
//
        }
        
    }
    
    
    /*
     
     - (NSError*)inSavePoint:(__attribute__((noescape)) void (^)(FMDatabase *db, BOOL *rollback))block {
     #if SQLITE_VERSION_NUMBER >= 3007000
         static unsigned long savePointIdx = 0;
         __block NSError *err = 0x00;
         FMDBRetain(self);
         dispatch_sync(_queue, ^() {
             
             NSString *name = [NSString stringWithFormat:@"savePoint%ld", savePointIdx++];
             
             BOOL shouldRollback = NO;
             
             if ([[self database] startSavePointWithName:name error:&err]) {
                 
                 block([self database], &shouldRollback);
                 
                 if (shouldRollback) {
                     // We need to rollback and release this savepoint to remove it
                     [[self database] rollbackToSavePointWithName:name error:&err];
                 }
                 [[self database] releaseSavePointWithName:name error:&err];
                 
             }
         });
         FMDBRelease(self);
         return err;
     #else
         NSString *errorMessage = NSLocalizedStringFromTable(@"Save point functions require SQLite 3.7", @"FMDB", nil);
         if (_db.logsErrors) NSLog(@"%@", errorMessage);
         return [NSError errorWithDomain:@"FMDatabase" code:0 userInfo:@{NSLocalizedDescriptionKey : errorMessage}];
     #endif
     }

     - (BOOL)checkpoint:(FMDBCheckpointMode)mode error:(NSError * __autoreleasing *)error
     {
         return [self checkpoint:mode name:nil logFrameCount:NULL checkpointCount:NULL error:error];
     }

     - (BOOL)checkpoint:(FMDBCheckpointMode)mode name:(NSString *)name error:(NSError * __autoreleasing *)error
     {
         return [self checkpoint:mode name:name logFrameCount:NULL checkpointCount:NULL error:error];
     }

     - (BOOL)checkpoint:(FMDBCheckpointMode)mode name:(NSString *)name logFrameCount:(int * _Nullable)logFrameCount checkpointCount:(int * _Nullable)checkpointCount error:(NSError * __autoreleasing _Nullable * _Nullable)error
     {
         __block BOOL result;

         FMDBRetain(self);
         dispatch_sync(_queue, ^() {
             result = [self.database checkpoint:mode name:name logFrameCount:logFrameCount checkpointCount:checkpointCount error:error];
         });
         FMDBRelease(self);
         
         return result;
     }

     */
    
}
