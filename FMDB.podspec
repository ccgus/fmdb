Pod::Spec.new do |s|
  s.name = 'FMDB'
  s.version = '2.7.7'
  s.summary = 'A Cocoa / Objective-C wrapper around SQLite.'
  s.homepage = 'https://github.com/ccgus/fmdb'
  s.license = 'MIT'
  s.author = { 'August Mueller' => 'gus@flyingmeat.com' }
  s.source = { :git => 'https://github.com/ccgus/fmdb.git', :tag => "#{s.version}" }
  s.requires_arc = true
  s.ios.deployment_target  = '9.0'
  s.osx.deployment_target  = '10.11'
  s.default_subspec = 'standard'  

  # use the built-in library version of sqlite3
  s.subspec 'standard' do |ss|
    ss.library = 'sqlite3'
    ss.source_files = 'src/fmdb/FM*.{h,m}'
    ss.exclude_files = 'src/fmdb.m'
    ss.header_dir = 'fmdb'
  end

  # use the built-in library version of sqlite3 with custom FTS tokenizer source files
  s.subspec 'FTS' do |ss|
    ss.source_files = 'src/extra/fts3/*.{h,m}'
    ss.dependency 'FMDB/standard'
  end
  
  # common_FTS: for internal use only
  s.subspec 'common_FTS' do |ss|
    ss.source_files = 'src/extra/fts3/*.{h,m}'		
    ss.pod_target_xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DSQLITE_ENABLE_FTS4 -DSQLITE_ENABLE_FTS4_UNICODE61 -DSQLITE_ENABLE_FTS3_PARENTHESIS -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_FTS3_TOKENIZER' }
  end
  

  # build the latest stable version of sqlite3
  s.subspec 'standalone' do |ss|
    ss.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DFMDB_SQLITE_STANDALONE' }
    ss.dependency 'sqlite3'
    ss.source_files = 'src/fmdb/FM*.{h,m}'
    ss.exclude_files = 'src/fmdb.m'
    ss.header_dir = 'fmdb'
  end

  # build with FTS support and custom FTS tokenizer source files
  s.subspec 'standalone-fts' do |ss|
    ss.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DFMDB_SQLITE_STANDALONE' }
    ss.source_files = 'src/fmdb/FM*.{h,m}', 'src/extra/fts3/*.{h,m}'
    ss.exclude_files = 'src/fmdb.m'
    ss.header_dir = 'fmdb'
    ss.dependency 'sqlite3/fts'
  end

  # use SQLCipher (which replaces sqlite3) and enable -DSQLITE_HAS_CODEC flag
  s.subspec 'SQLCipher' do |ss|
    ss.dependency 'SQLCipher', '~> 4.0'
    ss.source_files = 'src/fmdb/FM*.{h,m}'
    ss.exclude_files = 'src/fmdb.m'
	
    # SQLCipher/FTS:, SQLCipher replaces sqlite3 + FTS3 + custom FTS tokenizer source files
    ss.subspec 'FTS' do |sss|
	  sss.dependency 'FMDB/SQLCipher'
      sss.dependency 'SQLCipher/fts'
      sss.dependency 'FMDB/common_FTS'
	end
	
    ss.header_dir = 'fmdb'
    ss.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DSQLITE_ENABLE_FTS3_TOKENIZER -DHAVE_USLEEP=1 -DSQLCIPHER_CRYPTO', 'HEADER_SEARCH_PATHS' => 'SQLCipher' }
  end
  
end
