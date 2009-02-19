#
# Data map of Zotero database
#

require 'rubygems'
require 'activesupport'

require 'dm-core'
require 'dm-serializer'
require 'dm-types'
require 'dm-timestamps'

unless $test
  #actual_db = '/Users/jimmy/Library/Application Support/Firefox/Profiles/yuzcsq50.default/zotero/zotero.sqlite'
  actual_db = "#{Dir.pwd}/db/zotero.sqlite"

  user_db = 'sqlite3:///' + actual_db
  system_db = 'sqlite3:///' + actual_db

  $system_repository = :default # :system

  DataMapper.setup(:default, "sqlite3:///#{actual_db}")
  #DataMapper.setup($system_repository, system_db) unless $system_repository == :default
end

#
# System resource 
# 

class ItemType
  include DataMapper::Resource

  #def self.default_repository_name
  #  $system_repository
  #end

  storage_names[$system_repository] = 'itemTypes'

  property :id, Serial, :field => 'itemTypeID'
  property :name, String, :field => 'typeName'
  property :display, Enum[:hide, :display, :primary], :default => :display

  has n, :item_type_fields
  has n, :fields, :through => :item_type_fields
  has n, :base_field_mappings
  def base_fields
    fields - 
      base_field_mappings.map{|bf| bf.field} + 
      base_field_mappings.map{|bf| bf.base_field}
  end

  has n, :item_type_creator_types
  has n, :creator_types, :through => :item_type_creator_types

  def all_fields
    fields + creator_types
  end

  repository(:default) do
    has n, :items
  end
end

class Field
  include DataMapper::Resource

  #def self.default_repository_name
  #  $system_repository
  #end

  storage_names[$system_repository] = 'fields'

  property :id, Serial, :field => 'fieldID'
  property :name, String, :field => 'fieldName'

  #property :field_format_id, Integer, :field => 'fieldFormatID'
  #belongs_to :field_formats

  has n, :item_type_fields
  has n, :item_types, :through => :item_type_fields

  repository(:default) do
    has n, :item_datas
    def values
      item_datas.map{|ida| ida.value}
    end
  end
end

class ItemTypeField
  include DataMapper::Resource

  #def self.default_repository_name
  #  $system_repository
  #end

  storage_names[$system_repository] = 'itemTypeFields'

  property :item_type_id, Integer, :field => 'itemTypeID', :key => true
  property :field_id, Integer, :field => 'fieldID', :key => true
  property :hide, Integer
  property :position, Integer, :field => 'orderIndex'

  belongs_to :item_type
  belongs_to :field
end

class BaseFieldMapping
  include DataMapper::Resource

  #def self.default_repository_name
  #  $system_repository
  #end

  storage_names[$system_repository] = 'baseFieldMappings'

  property :item_type_id, Integer, :field => 'itemTypeID', :key => true
  property :base_field_id, Integer, :field => 'baseFieldID', :key => true
  property :field_id, Integer, :field => 'fieldID', :key => true

  belongs_to :item_type

  belongs_to :field
  belongs_to :base_field, :class_name => "Field", :child_key => [:base_field_id]
end

class CreatorType
  include DataMapper::Resource

  #def self.default_repository_name
  #  $system_repository
  #end

  storage_names[$system_repository] = 'creatorTypes'

  property :id, Serial, :field => 'creatorTypeID'
  property :name, Text, :field => 'creatorType'

  has n, :item_type_creator_types

  #repository(:default) do
  #  has n, :item_creators
  #  has n, :creators, :through => :item_creators
  #end
end

class ItemTypeCreatorType
  include DataMapper::Resource

  #def self.default_repository_name
  #  $system_repository
  #end

  storage_names[$system_repository] = 'itemTypeCreatorTypes'

  property :item_type_id, Integer, :field => 'itemTypeID', :key => true
  property :creator_type_id, Integer, :field => 'creatorTypeID', :key => true
  property :primary, Boolean, :field => 'primaryField', :default => false

  belongs_to :item_type
  belongs_to :creator_type
end

# 
# User Resource
#

class Item
  include DataMapper::Resource

  property :id, Serial, :field => 'itemID'
  property :item_type_id, Integer, :field => 'itemTypeID'
  property :created_at, DateTime, :field => 'dateAdded'
  property :updated_at, DateTime, :field => 'dateModified'

  repository($system_repository) do
    belongs_to :item_type
  end

  has n, :item_datas
  def values
    item_datas.map{|ida| ida.value}
  end

  has n, :item_creators
  has n, :creators, :through => :item_creators, :mutable => true

  def method_missing(m, *args)

    # Figure out if this is a setter or a getter
    setter = false
    if m.to_s =~ /(.*?)=$/
      setter = true 
      m = $1
      raise "Can only set one value" if args.size != 1
    end

    # special cases to get around fields named the same as existing methods
    m = 'repository' if m.to_s == '_repository'
    m = 'type' if m.to_s == '_type'

    # Get the field
    item_type_field = self.item_type.item_type_fields.first('field.name' => m.to_s)
    field = item_type_field.field if item_type_field
    unless field
      # Figure out the field from a base_field
      base_field_map = BaseFieldMapping.first('base_field.name' => m.to_s, 'item_type' => self.item_type)
      field = base_field_map.field if base_field_map
    end

    # bail out if no field was found
    return super unless field

    # TODO how come self.item_data.first(:field_id => field.id) doesn't work?
    data =  ItemData.first(:field_id => field.id, :item_id => self.id)

    # Give up if trying to get a value that doesn't exist
    return nil if !setter && !data

    if setter
      unless data
        # Create the ItemDataValue for the first time
        value = ItemDataValue.create :value => args.first
        data = ItemData.create(:field => field, :value => value, :item_id => self.id)
      else
        data.value.update_attributes(:value => args.first)
      end
    end
    data.value.value
  end
end

class ItemDataValue
  include DataMapper::Resource
  storage_names[:default] = 'itemDataValues'

  property :id, Serial, :field => 'valueID'
  property :value, Text

  has n, :item_datas
end

class ItemData
  include DataMapper::Resource
  storage_names[:default] = 'itemData'

  property :item_id, Integer, :field => 'itemID', :key => true
  property :field_id, Integer, :field => 'fieldID', :key => true
  property :value_id, Integer, :field => 'valueID', :key => true

  belongs_to :item
  belongs_to :field
  belongs_to :value, :class_name => "ItemDataValue", :child_key => [:value_id]
end

class Creator
  include DataMapper::Resource
  storage_names[:default] = 'creators'

  property :id, Serial, :field => 'creatorID'
  property :first_name, Text, :field => 'firstName'
  #property :middle_name, Text, :field => 'middleName'
  property :last_name, Text, :field => 'lastName'
  property :mode, Integer, :field => "fieldMode"
end

class ItemCreator
  include DataMapper::Resource
  storage_names[:default] = 'itemCreators'

  property :item_id, Integer, :field => 'itemID', :key => true
  property :creator_id, Integer, :field => 'creatorID', :key => true
  property :creator_type_id, Integer, :field => 'creatorTypeID', :default => 1, :key => true
  property :position, Integer, :field => 'orderIndex', :key => true

  belongs_to :item
  belongs_to :creator

  repository($system_repository) do
    belongs_to :creator_type
  end
end