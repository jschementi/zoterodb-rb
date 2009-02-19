$:.unshift "#{File.dirname(__FILE__)}/../"
require 'zoterodb'

include ZoteroDB::Models

# the Firefox zotero db
# DataMapper.setup :default, 'sqlite3:///Users/jimmy/Library/Application Support/Firefox/Profiles/yuzcsq50.default/zotero/zotero.sqlite'

# local copy of the zotero db
DataMapper.setup :default, "sqlite3:///#{Dir.pwd}/db/zotero.sqlite"

# user/system partitioned db
#DataMapper.setup :default, "sqlite3:///#{Dir.pwd}/db/user.sqlite"
#DataMapper.setup :system, "sqlite3:///#{Dir.pwd}/db/system.sqlite"

puts ZoteroDB::Formatting.format(ZoteroDB::Models::Item.all, :mla)