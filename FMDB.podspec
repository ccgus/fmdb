Pod::Spec.new do |s|
  s.name = 'FMDB'
  s.version = '2.6.2'
  s.summary = 'A Cocoa / Objective-C wrapper around SQLite.'
  s.homepage = 'https://github.com/ccgus/fmdb'
  s.license = 'MIT'
  s.author = { 'August Mueller' => 'gus@flyingmeat.com' }
  s.source = { :git => 'https://github.com/ccgus/fmdb.git', :tag => "#{s.version}" }
  s.requires_arc = true
  s.default_subspec = 'standard'

  # common: for internal use only
  s.subspec 'common' do |ss|
    ss.source_files = 'src/fmdb/FM*.{h,m}'
    ss.exclude_files = 'src/fmdb.m'
  end

  # common_FTS: for internal use only
  s.subspec 'common_FTS' do |ss|
    ss.source_files = 'src/extra/fts3/*.{h,m}'
    ss.pod_target_xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DSQLITE_ENABLE_FTS4=1 -DSQLITE_ENABLE_FTS3_PARENTHESIS=1' }
  end
  
  # standard: built-in library version of sqlite3
  s.subspec 'standard' do |ss|
    ss.library = 'sqlite3'
    ss.dependency 'FMDB/common'

    # standard/FTS: built-in library version of sqlite3 + custom FTS tokenizer source files
    ss.subspec 'FTS' do |sss|
      sss.dependency 'FMDB/common_FTS'
    end
  end

  # standalone: latest stable version of sqlite3
  s.subspec 'standalone' do |ss|
    ss.dependency 'sqlite3'
    ss.dependency 'FMDB/common'
    ss.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DFMDB_SQLITE_STANDALONE' }

    # standalone/FTS: latest stable version of sqlite3 + FTS3 + custom FTS tokenizer source files
    ss.subspec 'FTS' do |sss|
      sss.dependency 'sqlite3/fts'
      sss.dependency 'FMDB/common_FTS'
    end
  end

  # SQLCipher: SQLCipher replaces sqlite3
  s.subspec 'SQLCipher' do |ss|
    ss.dependency 'SQLCipher'
    ss.dependency 'FMDB/common'
    ss.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DHAVE_USLEEP=1' }   

    # SQLCipher/FTS:, SQLCipher replaces sqlite3 + FTS3 + custom FTS tokenizer source files
    ss.subspec 'FTS' do |sss|
      sss.dependency 'SQLCipher/fts'
      sss.dependency 'FMDB/common_FTS'
    end
  end  
end
