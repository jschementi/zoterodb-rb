require "#{File.dirname(__FILE__)}/../../../../spec/spec_helper"

def add_fields(item_type)
  f1 = Field.create :name => 'field1'
  f2 = Field.create :name => 'field2'
  itf1 = item_type.item_type_fields.create :field_id => f1.id, :hide => false
  itf2 = item_type.item_type_fields.create :field_id => f2.id, :hide => false
  [f1, f2, itf1, itf2]
end

def add_creator_types(item_type)
  c1 = CreatorType.create :name => 'author'
  c2 = CreatorType.create :name => 'editor'
  itct1 = item_type.item_type_creator_types.create :creator_type_id => c1.id
  itct2 = item_type.item_type_creator_types.create :creator_type_id => c2.id
  [c1, c2, itct1, itct2]
end

def add_base_field_mapping(item_type, f1)
  f3 = Field.create(:name => 'field3')
  [
    BaseFieldMapping.create(
      :item_type_id => item_type.id,
      :base_field_id => f3.id,
      :field_id => f1.id
    ),
    f3
  ]
end

def add_item_data(item_type_or_item, field)
  if item_type_or_item.kind_of?(Item)
    item = item_type_or_item
    item_type = item.item_type
  else
    item_type = item_type_or_item
    item = Item.create :item_type_id => item_type.id
  end
  value = ItemDataValue.create :value => "FieldValue #{rand}"
  [
    ItemData.create(
      :item_id => item.id,
      :field_id => field.id, 
      :item_data_value_id => value.id
    ),
    value
  ]
end

def add_item_creator(item, type_name, creator_data)
  creator = Creator.create(
    :creator_data_id => CreatorData.create(creator_data).id
  )
  creator_type = CreatorType.first :name => type_name
  [
    ItemCreator.create(
      :item_id => item.id, 
      :creator_id => creator.id,
      :creator_type_id => creator_type.id
    ),
    creator,
    creator_type
  ]
end

def add_notes_and_annotations(item)
  [
    item.item_notes.create(:title => "Note 1", :note => "This is a note body"),
    item.item_notes.create(:title => "Note 2", :note => "This is another note body"),
    item.item_annotations.create(:title => "Annotation 1", :value => "This is another annotation body"),
    item.item_annotations.create(:title => "Annotation 2", :value => "This is another annotation body")
  ]
end

def add_tags(item)
  t1 = ItemTag.find_or_create_tag item.id, :name => 'tag1'
  t2 = ItemTag.find_or_create_tag item.id, :name => 'tag2'
  [t1, t2]
end

describe ItemType do
  before(:each) do
    DataMapper.auto_migrate!
    @it = ItemType.create :name => 'testType'
  end

  it 'is creatable' do
    @it.new_record?.should == false
  end

  it 'is displayed by default' do
    @it.display.should == :display
  end

  it 'is displayed as primary' do
    @it.display = :primary
    @it.save.should == true
    @it.display.should == :primary
  end

  it 'is displayed as hidden' do
    @it.display = :hide
    @it.save.should == true
    @it.display.should == :hide
  end

  it 'has item-type fields' do
    _, _, itf1, itf2 = add_fields(@it)
    @it.item_type_fields.size.should == 2
    @it.item_type_fields.first.should == itf1
    @it.item_type_fields.last.should == itf2
  end

  it 'has fields' do
    f1, f2, _, _ = add_fields(@it)
    @it.fields.size.should == 2
    @it.fields.first.should == f1
    @it.fields.last.should == f2
  end

  it 'has base-field mappings' do
    f1, _, _, _ = add_fields(@it)
    bfm, _ = add_base_field_mapping(@it, f1)
    @it.base_field_mappings.size.should == 1
    @it.base_field_mappings.first.should == bfm
  end
  
  it 'has base-fields' do
    f1, _, _, _ = add_fields(@it)
    bfm, f = add_base_field_mapping(@it, f1)
    @it.base_fields.size.should == 2
    @it.base_fields[1].should == bfm.base_field
  end

  it 'has item-type creator-types' do
    _, _, itct1, itct2 = add_creator_types(@it)
    @it.item_type_creator_types.size.should == 2
    @it.item_type_creator_types.first.should == itct1
    @it.item_type_creator_types.last.should == itct2
  end

  it 'has creator-types' do
    c1, c2, _, _ = add_creator_types(@it)
    @it.creator_types.size.should == 2
    @it.creator_types.first.should == c1
    @it.creator_types.last.should == c2
  end

  it 'knows all its fields' do
    add_fields(@it)
    add_creator_types(@it)
    @it.all_fields.should == (@it.fields + @it.creator_types)
  end
  
  it 'has items' do
    Item.create :item_type_id => @it.id
    Item.create :item_type_id => @it.id
    Item.create :item_type_id => @it.id
    @it.items.size.should == 3
  end
end

describe Field do
  before(:each) do
    DataMapper.auto_migrate!
    itemdata = ItemType.create(:name => "foo")
    @f1, _, @itf1, _ = add_fields(itemdata)
    @id, _ = add_item_data(itemdata, @f1)
  end

  it 'is creatable' do
    @f1.new_record?.should == false
    @f1.name.should == 'field1'
    @f1.id.kind_of?(Integer).class == Integer
  end

  it 'has item-type fields' do
    @f1.item_type_fields.size.should == 1
    @f1.item_type_fields[0].should == @itf1
  end

  it 'has item-types' do
    @f1.item_types.size.should == 1
    @f1.item_types[0].should == @itf1.item_type
  end

  it 'has item_datas' do
    @f1.item_datas.size.should == 1
    @f1.item_datas[0].should == @id
  end

  it 'has values' do
    @f1.values.size.should == 1
    (@f1.values[0].value =~ /FieldValue/).should_not be_nil
  end
end

describe ItemTypeField do
  before(:each) do
    DataMapper.auto_migrate!
    @it = ItemType.create :name => "foo"
    @f1, @f2, @itf1, @itf2 = add_fields(@it)
  end
  
  it 'belongs to a item_type' do
    @itf1.item_type.should == @it
    @itf2.item_type.should == @it
  end

  it 'belongs to a field' do
    @itf1.field.should == @f1
    @itf2.field.should == @f2
  end

  it 'is a list, scoped by item_type' do
    it1 = ItemType.create :name => 'bogus1'
    it2 = ItemType.create :name => 'bogus2'
    f1, f2, itf1, itf2 = add_fields(it1)
    f3, f4, itf3, itf4 = add_fields(it2)
    itf1.position.should == 1
    itf2.position.should == 2
    itf3.position.should == 1
    itf4.position.should == 2
  end

  it 'can be hidden' do
    @itf1.hide.should be_false
    @itf1.hide = true
    @itf1.save.should be_true
    @itf1.save.should be_true
  end

  it 'has a position' do
    @itf1.position.should == 1
    @itf2.position.should == 2
  end
end

describe BaseFieldMapping do
  before(:each) do
    DataMapper.auto_migrate!
    @it = ItemType.create :name => 'foo'
    @f1, @f2, @itf1, @itf2 = add_fields(@it)
    @bfm, @f3 = add_base_field_mapping(@it, @f1)
  end
  
  it 'belongs to a field' do
    @bfm.field.should == @f1
  end
  
  it 'belongs to a base_field' do
    @bfm.base_field.should == @f3
  end
  
  it 'belongs to an item_type' do
    @bfm.item_type.should == @it
  end
end

describe CreatorType do
  before(:each) do
    DataMapper.auto_migrate!
    @it = ItemType.create :name => 'bar'
    @ct1, @ct2, @itct1, @itct2 = add_creator_types(@it)
    @i = Item.create :item_type_id => @it.id
    @ic, @c, @ct = add_item_creator(@i, 'author',
      :first_name => "Jimmy",
      :middle_name => "Michael",
      :last_name => "Schementi"
    )
  end

  it 'has a name' do
    @ct1.name.kind_of?(String).should be_true
  end

  it 'has item_type_creator_types' do
    @ct1.item_type_creator_types.size.should == 1
    @ct1.item_type_creator_types[0].should == @itct1
  end

  it 'has item_creators' do
    @ct.item_creators.size.should == 1
    @ct.item_creators[0].should == @ic
  end

  it 'has creators' do
    @ct.creators.size.should == 1
    @ct.creators[0].should == @ic.creator
  end
end

describe ItemTypeCreatorType do
  before(:each) do
    DataMapper.auto_migrate!
    @it = ItemType.create :name => 'bar'
    @ct1, @ct2, @itct1, @itct2 = add_creator_types(@it)
  end

  it 'belongs to a item_type' do
    @itct1.item_type.should == @it
    @itct2.item_type.should == @it
  end

  it 'belongs to a creator type' do
    @itct1.creator_type.should == @ct1
    @itct2.creator_type.should == @ct2
  end
  
  it 'can be a primary creator type' do
    @itct1.primary.should be_false
    @itct1.primary = true
    @itct1.save.should be_true
    @itct1.primary.should be_true
  end
end

#
# User
#

describe Item do
  before(:each) do
    DataMapper.auto_migrate!
    @it = ItemType.create :name => "Item Type 123"
    @f1, @f2, @itf1, @itf2 = add_fields(@it)
    @i = Item.create :item_type_id => @it.id
    @id, _ = add_item_data(@i, @f1)
    add_creator_types(@it)
    @ic, _, _ = add_item_creator(@i, 'author', {
      :first_name => "Jimmy",
      :middle_name => "Michael",
      :last_name => "Schementi"
    })
    @in1, @in2, @ia1, @ia2 = add_notes_and_annotations(@i)
    @t1, @t2 = add_tags(@i)
  end

  it 'knows when it was created/modified' do
    @i.created_at.kind_of?(DateTime).should be_true
    @i.updated_at.kind_of?(DateTime).should be_true
  end

  it 'belongs to an item_type' do
    @i.item_type.should == @it
  end

  it 'has many item_datas' do
    @i.item_datas.size.should == 1
    @i.item_datas[0].should == @id
  end
  
  it 'has many values' do
    @i.values.size.should == 1
    @i.values[0].should == @id.value
  end
  
  it 'has many item_creators' do
    @i.item_creators.size.should == 1
    @i.item_creators[0].should == @ic
  end
  
  it 'has many creators' do
    @i.creators.size.should == 1
    @i.creators[0].should == @ic.creator
  end

  it 'has item_tags' do
    @i.item_tags.size.should == 2
    @i.item_tags[0].should == @t1
    @i.item_tags[1].should == @t2
  end

  it 'has tags' do
    @i.tags.size.should == 2
    @i.tags[0].should == @t1.tag
    @i.tags[1].should == @t2.tag
  end

  it 'gets field values with a dot notation' do
    @i.field1.class.should == FieldType::Line
    @i.field1.to_s.should =~ /FieldValue/
  end

  it 'sets field values with a dot notation' do
    @i.field1 = 'New Field Value'
    @i.field1.to_s.should =~ /New Field Value/
  end

  it 'gets creator values with array indexing' do
    @i['author'].size.should == 1
    @i['author'].first.creator.creator_data.middle_name.should == 'Michael'
  end

  it 'sets creator values with array indexing' do
    name = {:first => 'Michael', :middle => 'Thomas', :last => 'Schementi'}
    @i['author'].size.should == 1
    @i['author'] = name
    @i['author'].last.creator.creator_data.first_name.
      should == name[:first]
    @i['author'].last.creator.creator_data.middle_name.
      should == name[:middle]
    @i['author'].last.creator.creator_data.last_name.
      should == name[:last]
  end

  it 'has notes' do
    @i.notes.should == "#{@in1.note}\n\n#{@in2.note}"
  end

  it 'has annotations' do
    @i.annotations.should == "#{@ia1.value}\n\n#{@ia2.value}"
  end
end

describe ItemDataValue do
  before(:each) do
    DataMapper.auto_migrate!
    @it = ItemType.create :name => 'baz'
    @f1, _, @itf1, _ = add_fields(@it)
    @id, @idv = add_item_data(@it, @f1)
  end
  
  it 'has a value' do
    @idv.value.kind_of?(String).should be_true
  end
  
  it 'has item-datas' do
    @idv.item_datas.size.should == 1
    @idv.item_datas[0].should == @id
  end
end

describe ItemData do
  before(:each) do
    DataMapper.auto_migrate!
    @it = ItemType.create :name => 'baz'
    @f1, _, @itf1, _ = add_fields(@it)
    @id, _ = add_item_data(@it, @f1)
  end
  
  it 'belongs to an item' do
    @id.item.should_not be_nil
    @id.item.kind_of?(Item).should be_true
  end
  
  it 'belongs to a field' do
    @id.field.should == @f1
  end
  
  it 'belongs to a item_data_value' do
    @id.item_data_value.kind_of?(ItemDataValue).should be_true
  end
  
  it 'has a value' do
    @id.value.should == @id.item_data_value
  end
end

describe CreatorData do
  before(:each) do
    DataMapper.auto_migrate!
    @cd = CreatorData.create({
      :first_name => "Felicia",
      :last_name => "Cutrone",
      :middle_name => "Marie",
      :birth_year => 1986
    })
    @c = Creator.create(:creator_data_id => @cd.id)
  end
  
  it 'is creatable' do
    @cd.new_record?.should be_false
  end
  
  it 'has a mode which decides whether the last name should be parsed' do
    @cd.mode.should == 0
    @cd.mode = 1
    @cd.save.should be_true
    @cd.mode.should == 1
  end
  
  it 'has creators' do
    @cd.creators[0].should == @c
  end
  
  it 'formats as full name' do
    @cd.full_name.should == 'Cutrone, Felicia M.'
  end
  
end

describe Creator do
  before(:each) do
    DataMapper.auto_migrate!
    @cd = CreatorData.create({
      :first_name => "Felicia",
      :last_name => "Cutrone",
      :middle_name => "Marie",
      :birth_year => 1986
    })
    @c = Creator.create(:creator_data_id => @cd.id)
  end
  
  it 'belongs to creator_data' do
    @c.creator_data.should == @cd
  end
  
  it 'builds a creator data for you' do
    creator = Creator.build_with_data('Schementi', 'Jimmy')
    creator.creator_data.last_name.should == "Schementi"
    creator.creator_data.first_name.should == "Jimmy"
  end
  
  it 'sets a unique key before being created' do
    c1 = Creator.create :creator_data_id => CreatorData.create.id
    c2 = Creator.create :creator_data_id => CreatorData.create.id
    c1.key.should_not == c2.key
  end
  
  it 'knows when it was created/modified' do
    @c.created_at.kind_of?(DateTime).should be_true
    @c.updated_at.kind_of?(DateTime).should be_true
  end
end

describe ItemCreator do
  before(:each) do
    DataMapper.auto_migrate!
    @it = ItemType.create :name => 'bar'
    @ct1, @ct2, @itct1, @itct2 = add_creator_types(@it)
    @i = Item.create :item_type_id => @it.id
    @ic, @c, @ct = add_item_creator(@i, 'author',
      :first_name => "Jimmy",
      :middle_name => "Michael",
      :last_name => "Schementi"
    )
  end
  
  it 'belongs to a item' do
    @ic.item.should == @i
  end
  
  it 'belongs to a creator' do
    @ic.creator.should == @c
  end
  
  it 'belongs to a creator_type' do
    @ic.creator_type.should == @ct
  end
  
  it 'is a list, scoped by items' do
    @it1 = ItemType.create :name => 'bar'
    @i1 = Item.create :item_type_id => @it1.id
    @ic1, _, _ = add_item_creator(@i1, 'author',
      :first_name => "Jimmy",
      :middle_name => "Michael",
      :last_name => "Schementi"
    )
    @ic2, _, _ = add_item_creator(@i1, 'author',
      :first_name => "Felicia",
      :middle_name => "Marie",
      :last_name => "Cutrone"
    )
    @it2 = ItemType.create :name => 'baz'
    @i2 = Item.create :item_type_id => @it2.id
    @ic3, _, _ = add_item_creator(@i2, 'author',
      :first_name => "Boom",
      :middle_name => "A",
      :last_name => "Rang"
    )
    @ic4, _, _ = add_item_creator(@i2, 'author',
      :first_name => "I",
      :middle_name => "P",
      :last_name => "Freely"
    )
    
    @ic1.position.should == 1
    @ic2.position.should == 2
    @ic3.position.should == 1
    @ic4.position.should == 2
  end
  
  it 'has a position' do
    @ic.position.should == 1
  end
  
  it 'defaults to *author* as the creator-type' do
    ic = ItemCreator.create :item_id => @i.id, 
      :creator_id => Creator.build_with_data("Bar", "Foo").id
    ic.creator_type.name.should == 'author'
  end
end

describe ItemNote do
  before(:each) do
    DataMapper.auto_migrate!
    itemtype = ItemType.create :name => 'foo'
    @item = Item.create :item_type_id => itemtype.id
    @note = ItemNote.create :item_id => @item.id, :title => "hi", :note => 'bye'
  end

  it 'is creatable' do
    @note.new_record?.should be_false
  end

  it 'belongs to an item' do
    @note.item.should == @item
  end
end

describe ItemAnnotation do
end

describe Tag do
end

describe ItemTag do
end

describe ItemAttachment do
  before(:each) do
    DataMapper.auto_migrate!
    it = ItemType.create :name => 'foo'
    @i = Item.create :item_type_id => it.id
    @a = ItemAttachment.create :item_id => @i.id, 
      :mime_type => 'image/jpeg',
      :path => 'db/item_attachments/foo.jpg', 
      :original_path => 'foo.jpg'
  end

  it 'is creatable' do
    @a.new_record?.should be_false
  end

  it 'belongs to an item' do
    @a.item.should == @i
  end

  it 'has a filename' do
    @a.filename.should == File.basename(@a.path)
  end

  it 'has a default storage path' do
    ItemAttachment.storage_path.should == if defined? RAILS_ROOT
      File.expand_path(File.join(RAILS_ROOT, 'db', 'item_attachments'))
    else
      File.expand_path(File.join(File.dirname(__FILE__), '..', 'db', 'item_attachments'))
    end
  end

  it 'can set storage path' do
    new_store = File.expand_path(File.join(File.dirname(__FILE__), 'store'))
    ItemAttachment.storage_path = new_store
    ItemAttachment.storage_path.should == new_store
  end

  it 'has a real path' do
    @a.real_path.should == File.join(
      ItemAttachment.storage_path,
      ("%06d" % @a.id).scan(/.../),
      @a.filename
    )
  end

  it 'saves a file' do
    ItemAttachment.storage_path = File.join File.dirname(__FILE__), 'store'
    tmp = File.join File.dirname(__FILE__), 'tmp.jpg'
    File.delete(tmp) if File.exist?(tmp)
    File.open(tmp, 'w'){ |f| f.write 'Hello!' }

    f = mock("TempFile", :mime_type => 'image/jpeg', :size => 6, 
      :original_filename => tmp, :original_path => tmp, :local_path => tmp,
      :content_type => 'image/jpeg')

    ia = ItemAttachment.create_and_store(:uploaded_data => f, :item_id => @i.id)

    File.exist?(ia.real_path).should be_true
    File.open(ia.real_path, 'r'){ |f| f.read }.should == 'Hello!'

    ia.original_path.should == tmp
    ia.path.should == File.basename(tmp)
    
    File.delete(tmp) if File.exist?(tmp)
  end
end

describe Project do
  before(:each) do
    DataMapper.auto_migrate!
    @c = Project.create :name => 'My Collection'
  end

  it 'is creatable' do
    @c.new_record?.should be_false
  end
end

describe ProjectItem do
  before(:each) do
    DataMapper.auto_migrate!
    it = ItemType.create :name => 'foo'
    @i = Item.create :item_type_id => it.id
    @c = Project.create :name => 'My Collection'
    @ci = ProjectItem.create :project_id => @c.id, :item_id => @i.id
  end

  it 'is creatable' do
    @ci.new_record?.should be_false
  end

  it 'belongs to a project' do
    @ci.project.should == @c
  end

  it 'belongs to a item' do 
    @ci.item.should == @i
  end

  it 'is a list' do
    @ci.position.should == 1
  end
end
