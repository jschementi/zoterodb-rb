$test = true
require 'rubygems'
require 'bacon'

require 'dm-core'
DataMapper.setup(:default, 'sqlite3::memory:')

require 'models'

DataMapper.auto_migrate!

describe 'ItemType' do

  should 'leap tall buildings' do
    
  end
  
end