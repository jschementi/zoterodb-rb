require 'digest/sha1'

require 'rubygems'
require 'activesupport'

require 'dm-core'
require 'dm-serializer'
require 'dm-types'
require 'dm-timestamps'
require 'dm-is-list'
require 'dm-validations'

require 'fileutils'
require 'ftools'

#
# Data map of Zotero database
#
module ZoteroDB::Models

  SYSTEM_REPOSITORY = :default

  #
  # System resource 
  # 

  class ItemType
    include DataMapper::Resource

    #def self.default_repository_name
    #  SYSTEM_REPOSITORY
    #end

    storage_names[SYSTEM_REPOSITORY] = 'itemTypes'

    property :id, Serial, :field => 'itemTypeID'
    property :name, String, :field => 'typeName'
    property :display, Enum[:hide, :display, :primary], :default => :display

    def self.int_to_display(int_value)
      return :hide if int_value == 0
      return :display if int_value == 1
      return :primary if int_value == 2
    end

    has n, :item_type_fields, :order => ['position']
    def fields
      item_type_fields.map{|itf| itf.field}
    end
    # TODO: though item_type_fields is sorted by position, the fields aren't
    # when using the below commented out line.
    #has n, :fields, :through => :item_type_fields

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

    DM_CONFLICT_MAP = %W(type repository).inject({}) do |map, thing|
      map[thing] = "___#{thing}"; map
    end

    def safe_name
      DM_CONFLICT_MAP[name] || name
    end

    def self.real_name(safe_name)
      DM_CONFLICT_MAP.index(safe_name)
    end

    #def self.default_repository_name
    #  SYSTEM_REPOSITORY
    #end

    storage_names[SYSTEM_REPOSITORY] = 'fields'

    property :id, Serial, :field => 'fieldID'
    property :name, String, :field => 'fieldName'

    #property :field_format_id, Integer, :field => 'fieldFormatID'
    #belongs_to :field_formats

    has n, :item_type_fields, :order => ['position']
    def item_types
      item_type_fields.map{|itf| itf.item_type}
    end
    # TODO: though item_type_fields is sorted by position, the fields aren't
    # when using the below commented out line.
    #has n, :item_types, :through => :item_type_fields

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
    #  SYSTEM_REPOSITORY
    #end

    storage_names[SYSTEM_REPOSITORY] = 'itemTypeFields'

    property :item_type_id, Integer, :field => 'itemTypeID', :key => true
    property :field_id, Integer, :field => 'fieldID', :key => true
    property :hide, Boolean, :default => false
    property :position, Integer, :field => 'orderIndex'

    is :list, :scope => [:item_type_id]

    belongs_to :item_type
    belongs_to :field
  end

  class BaseFieldMapping
    include DataMapper::Resource

    #def self.default_repository_name
    #  SYSTEM_REPOSITORY
    #end

    storage_names[SYSTEM_REPOSITORY] = 'baseFieldMappings'

    property :item_type_id, Integer, :field => 'itemTypeID', :key => true
    property :base_field_id, Integer, :field => 'baseFieldID', :key => true
    property :field_id, Integer, :field => 'fieldID', :key => true

    belongs_to :item_type

    belongs_to :field
    belongs_to :base_field, :class_name => "Field", 
      :child_key => [:base_field_id]
  end

  class CreatorType
    include DataMapper::Resource

    #def self.default_repository_name
    #  SYSTEM_REPOSITORY
    #end

    storage_names[SYSTEM_REPOSITORY] = 'creatorTypes'

    property :id, Serial, :field => 'creatorTypeID'
    property :name, Text, :field => 'creatorType', :lazy => false

    has n, :item_type_creator_types

    repository(:default) do
      has n, :item_creators
      has n, :creators, :through => :item_creators
    end
  end

  class ItemTypeCreatorType
    include DataMapper::Resource

    #def self.default_repository_name
    #  SYSTEM_REPOSITORY
    #end

    storage_names[SYSTEM_REPOSITORY] = 'itemTypeCreatorTypes'

    property :item_type_id, Integer, 
      :field => 'itemTypeID', :key => true
    property :creator_type_id, Integer, 
      :field => 'creatorTypeID', :key => true
    property :primary, Boolean, 
      :field => 'primaryField', :default => false

    belongs_to :item_type
    belongs_to :creator_type
  end

  # 
  # User Resource
  #

  class Item
    include DataMapper::Resource
    storage_names[:default] = 'items'

    property :id, Serial, :field => 'itemID'
    property :item_type_id, Integer, :field => 'itemTypeID'
    property :created_at, DateTime, :field => 'dateAdded'
    property :updated_at, DateTime, :field => 'dateModified'

    repository(SYSTEM_REPOSITORY) do
      belongs_to :item_type
    end

    has n, :item_datas
    def values; item_datas.map{|ida| ida.value} end

    has n, :item_notes
    def notes; item_notes.map{|n| n.note}.join("\n\n"); end

    has n, :item_annotations
    def annotations; item_annotations.map{|n| n.value}.join("\n\n"); end

    has n, :item_creators
    has n, :creators, :through => :item_creators

    has n, :item_tags
    has n, :tags, :through => :item_tags
    def tag_list
      tags.map{|t| t.name}.join(", ")
    end

    has n, :item_attachments

    # indexers to access creators
    def [](index)
      ct, _ = check_creator_type(index, self.item_type)
      ItemCreator.all :item_id => self.id, :creator_type_id => ct.id
    end
    
    # indexers to set creators
    # index: creator type name
    # value: Hash with keys (last, first, middle)
    # TODO: should this really just be an indexer?
    # How about appending? How do I remove a creator?
    def []=(index, value)
      ct, _ = check_creator_type(index, self.item_type)
      c = Creator.build_with_data value[:last], value[:first], value[:middle]
      opts = {
        :item_id         => self.id,
        :creator_id      => c.id,
        :creator_type_id => ct.id
      }
      ic   = ItemCreator.first  opts
      ic ||= ItemCreator.create opts
      ItemCreator.all :item_id => self.id, :creator_type_id => ct.id
    end

    # get and set fields
    # TODO: Clean this method up, it's way too big. Why wasn't it this big
    # with the old models?
    def method_missing(m, *args)
      # Figure out if this is a setter or a getter
      setter = false
      if m.to_s =~ /(.*?)=$/
        setter = true 
        m = $1
        raise "Can only set one value" if args.size != 1
      end

      # special cases to get around fields named the same as existing methods
      m = Field.real_name(m.to_s) || m

      # Make sure the field isn't a multi-parameter field. If so, do the
      # necessary conversions.
      m, property = if Field.respond_to?(:get_actual_name_and_property)
        Field.get_actual_name_and_property(m.to_s)
      else
        [m.to_s, nil]
      end

      # Get the field
      item_type_field = self.item_type.item_type_fields.
        first('field.name' => m.to_s)
      field = item_type_field.field if item_type_field
      unless field
        # Figure out the field from a base_field
        base_field_map = BaseFieldMapping.first('base_field.name' => m.to_s, 
          :item_type_id => self.item_type_id)
        field = base_field_map.field if base_field_map
      end

      # bail out if no field was found
      return super unless field

      data =  ItemData.first(:field_id => field.id, :item_id => self.id)

      # Give up if trying to get a value that doesn't exist
      return nil if !setter && !data

      if setter

        # Typecast the value being set
        data_value = if field.respond_to?(:field_type)
          if property
            _type = data ? 
              field.field_type.new(data.value.value) : 
              field.field_type.new
            _type.send("#{property}=", args.first)
            _type
          else
            field.field_type.new(args.first)
          end.to_s
        else
          # If for some reason we don't know the field type,
          # don't bother to typecast
          args.first.to_s
        end

        value = ItemDataValue.first(:value => data_value) ||
          ItemDataValue.create(:value => data_value)

        unless data
          data = ItemData.create(:field => field,
            :item_data_value => value, :item_id => self.id)
        else
          data.update_attributes(:item_data_value_id => value.id)
        end
      end

      if data.respond_to?(:typecast_value) && !property
        data.typecast_value
      elsif data.respond_to?(:typecast_value) && property :
        data.typecast_value.send(property)
      else
        data.value.value
      end
    end
    
    private
      def check_creator_type(index, item_type)
        ct = CreatorType.first :name => index.to_s
        raise "Creator Type \"#{index}\" doesn't exist" unless ct
        itct = ItemTypeCreatorType.first(
          :item_type_id    => item_type.id,
          :creator_type_id => ct.id
        )
        raise "Creator Type \"#{index}\" is not valid for a #{item_type.name}" unless itct
        [ct, itct]
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
    property :item_data_value_id, Integer, :field => 'valueID', :key => true

    belongs_to :item
    belongs_to :field
    belongs_to :item_data_value

    def value
      item_data_value
    end
  end

  class CreatorData
    include DataMapper::Resource
    storage_names[:default] = 'creatorData'

    property :id, Serial, :field => 'creatorDataID'
    property :first_name, Text, :field => 'firstName'
    property :middle_name, Text, :field => 'shortName'
    property :last_name, Text, :field => 'lastName'
    property :mode, Integer, :field => "fieldMode", :default => 0
    property :birth_year, Integer, :field => 'birthYear'

    has n, :creators
    
    def full_name
      "#{last_name}, #{first_name}#{ " #{middle_name}" if middle_name }"
    end
  end

  class Creator
    include DataMapper::Resource
    storage_names[:default] = 'creators'

    property :id, Serial, :field => 'creatorID'
    property :creator_data_id, Integer, :field => 'creatorDataID'
    property :created_at, DateTime, :field => 'dateAdded'
    property :updated_at, DateTime, :field => 'dateModified'
    property :unique_key, Text, :field => 'key'

    before(:create) do
      while self.unique_key.nil? || Creator.first(:unique_key => self.unique_key)
        self.unique_key = Digest::SHA1.hexdigest("--#{Time.now}--")
      end
    end

    belongs_to :creator_data

    has n, :item_creators

    def self.build_with_data(last, first, middle = nil)
      last   = nil if last.blank?
      first  = nil if first.blank?
      middle = nil if middle.blank?
      data_opts      = {
        :first_name => first,
        :middle_name => middle,
        :last_name => last
      }
      creator_data   = CreatorData.first(data_opts)
      creator_data ||= CreatorData.create(data_opts)
      creator_opts   = {:creator_data_id => creator_data.id}
      creator        = Creator.first(creator_opts)
      creator      ||= Creator.create(creator_opts)
      creator
    end
  end

  class ItemCreator
    include DataMapper::Resource
    storage_names[:default] = 'itemCreators'

    property :item_id, Integer, :field => 'itemID', :key => true
    property :creator_id, Integer, :field => 'creatorID', :key => true
    property :creator_type_id, Integer, :field => 'creatorTypeID', :key => true
    property :position, Integer, :field => 'orderIndex'

    is :list, :scope => [:item_id]

    belongs_to :item
    belongs_to :creator

    before :valid?, :set_default_creator_type
  
    def set_default_creator_type(context = :default)
      if self.creator_type_id.nil?
        ct = CreatorType.first(:name => 'author')
        self.creator_type_id = ct.id unless ct.nil?
      end
    end

    repository(SYSTEM_REPOSITORY) do
      belongs_to :creator_type
    end
  end

  class ItemNote
    include DataMapper::Resource
    storage_names[:default] = "itemNotes"

    property :id, Serial, :field => 'itemID'
    property :item_id, Integer, :field => 'sourceItemID'
    property :note, Text
    property :title, Text

    belongs_to :item
  end

  class ItemAnnotation
    include DataMapper::Resource
    storage_names[:default] = 'annotations'

    property :id, Serial, :field => 'annotationID'
    property :title, Text, :field => 'parent'
    property :value, Text, :field => 'text'
    property :item_id, Integer, :field => 'itemID'

    belongs_to :item
  end

  class Tag
    include DataMapper::Resource
    storage_names[:default] = 'tags'

    property :id, Serial, :field => 'tagID'
    property :name, Text, :nullable => false, :unique => true, :lazy => false
    property :created_at, DateTime, :field => 'dateAdded'
    property :updated_at, DateTime, :field => 'dateModified'
    property :unique_key, Text, :field => 'key'
    property :ttype, Integer, :field => 'type', :nullable => false

    before(:create) do
      while self.unique_key.nil? || Tag.first(:unique_key => self.unique_key)
        self.unique_key = Digest::SHA1.hexdigest("--#{Time.now}--")
      end
      self.ttype ||= 0
    end

    has n, :item_tags
    has n, :items, :through => :item_tags
  end

  class ItemTag
    include DataMapper::Resource
    storage_names[:default] = 'itemTags'

    property :item_id, Integer, :field => 'itemID', :key => true
    property :tag_id, Integer, :field => 'tagID', :key => true

    belongs_to :tag
    belongs_to :item

    def self.find_or_create_tag(item_id, options)
      options = {:ttype => 0}.merge(options) # Zotero requires a itemTags.type field
      t   = Tag.first options
      t ||= Tag.create options
      unless t.new_record?
        create :item_id => item_id, :tag_id => t.id
      else
        raise Exception.new(t.errors)
      end
    end
  end

  class ItemAttachment
    include DataMapper::Resource
    storage_names[:default] = 'itemAttachments'

    property :id, Serial, :field => 'itemID'
    property :item_id, Integer, :field => 'sourceItemID'
    property :mime_type, String, :field => 'mimeType'
    property :path, Text
    property :original_path, Text, :field => 'originalPath'

    belongs_to :item

    def self.storage_path
      @storage_path
    end
    def self.storage_path=(value)
      @storage_path = value
    end
    self.storage_path = File.expand_path(File.join(
      defined?(RAILS_ROOT) ?
        RAILS_ROOT :
        File.join(File.dirname(__FILE__), '..', '..'),
      'db', 'item_attachments'
    ))

    def filename
      File.basename path
    end

    def real_path
      File.join(
        File.expand_path(self.class.storage_path),
        partitioned_path, 
        self.filename
      )
    end

    def self.create_and_store(options)
      upload = options[:uploaded_data]
      item = Item.get(options[:item_id] || options[:reference_id])
      ia = create(
        :item_id => item.id,
        :mime_type => upload.content_type,
        :path => File.basename(upload.original_filename),
        :original_path => upload.original_path
      )
      ia.store(upload)
      ia
    end

    def store(upload)
      path = File.dirname self.real_path
      File.makedirs(path)
      FileUtils.mv(upload.local_path, self.real_path)
    end

    private

      # Partition the path according to the id
      def partitioned_path
        ("%06d" % self.id).scan(/.../)
      end
  end

  class Project
    include DataMapper::Resource
    storage_names[:default] = 'collections'

    property :id, Serial, :field => 'collectionID'
    property :name, String, :field => 'collectionName'
    property :project_id, Integer, :field => 'parentCollectionID'
    property :created_at, DateTime, :field => 'dateAdded'
    property :updated_at, DateTime, :field => 'dateModified'
    property :unique_key, Text, :field => 'key'

    before(:create) do
      while self.unique_key.nil? || Project.first(:unique_key => self.unique_key)
        self.unique_key = Digest::SHA1.hexdigest("--#{Time.now}--")
      end
    end

    belongs_to :project
  end
  
  class ProjectItem
    include DataMapper::Resource
    storage_names[:default] = 'collectionItems'

    property :project_id, Integer, :field => 'collectionID', :key => true
    property :item_id, Integer, :field => 'itemID', :key => true
    property :position, Integer, :field => 'orderIndex'

    is :list, :scope => [:project_id]

    belongs_to :project
    belongs_to :item
  end
end
