Pod::Spec.new do |s|
  s.name = 'FMDB'
  s.version = '2.7.12'
  s.summary = 'A Cocoa / Objective-C wrapper around SQLite.'
  s.homepage = 'https://github.com/ccgus/fmdb'
  s.license = 'MIT'
  s.author = { 'August Mueller' => 'gus@flyingmeat.com' }
  s.source = { :git => 'https://github.com/ccgus/fmdb.git', :tag => "#{s.version}" }
  s.requires_arc = true
  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.13'
  s.watchos.deployment_target = '7.0'
  s.tvos.deployment_target = '12.0'
  s.cocoapods_version = '>= 1.12.0'
  s.default_subspec = 'standard'

  s.subspec 'Core' do |ss|
    ss.source_files = 'src/fmdb/FM*.{h,m}'
    ss.exclude_files = 'src/fmdb.m'
    ss.header_dir = 'fmdb'
    ss.resource_bundles = { 'FMDB_Privacy' => 'privacy/PrivacyInfo.xcprivacy' }
  end

  # use the built-in library version of sqlite3
  s.subspec 'standard' do |ss|
    ss.dependency 'FMDB/Core'
    ss.library = 'sqlite3'
  end

  # use the built-in library version of sqlite3 with custom FTS tokenizer source files
  s.subspec 'FTS' do |ss|
    ss.dependency 'FMDB/standard'
    ss.source_files = 'src/extra/fts3/*.{h,m}'
  end

  # build the latest stable version of sqlite3
  s.subspec 'standalone' do |ss|
    ss.dependency 'FMDB/Core'
    ss.dependency 'sqlite3', '~> 3.46'
    ss.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DFMDB_SQLITE_STANDALONE' }
  end

  # build with FTS support and custom FTS tokenizer source files
  s.subspec 'standalone-fts' do |ss|
    ss.dependency 'FMDB/Core'
    ss.dependency 'sqlite3/fts', '~> 3.46'
    ss.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DFMDB_SQLITE_STANDALONE' }
    ss.source_files = 'src/extra/fts3/*.{h,m}'
  end

  # use SQLCipher and enable -DSQLITE_HAS_CODEC flag
  s.subspec 'SQLCipher' do |ss|
    ss.dependency 'FMDB/Core'
    ss.dependency 'SQLCipher', '~> 4.6'
    ss.xcconfig = { 'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DHAVE_USLEEP=1 -DSQLCIPHER_CRYPTO', 'HEADER_SEARCH_PATHS' => 'SQLCipher' }
  end
end
