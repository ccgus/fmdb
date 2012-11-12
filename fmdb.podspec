Pod::Spec.new do |s|
  s.name     = 'fmdb'
  s.version  = '2.0build'
  s.summary  = 'A Cocoa / Objective-C wrapper around SQLite.'
  s.homepage = 'https://github.com/ccgus/fmdb'
  s.license  = 'MIT'
  s.author   = { 'August Mueller' => 'gus@flyingmeat.com' }
  s.source   = { :git => 'git@boohee-apple:/opt/git/Plugins/FMDB.git', :tag => "2.0build"}
  s.source_files = 'build/Release-lipo/include/*.h'
  s.libraries = 'sqlite3', "FMDB"
  s.preserve_paths = 'build/Release-lipo/libFMDB.a'
end