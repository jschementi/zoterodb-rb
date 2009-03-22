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

def add_base_field_mapping(item_type)
  BaseFieldMapping.create :item_type_id => item_type.id,
    :base_field_id => Field.create(:name => 'field3').id,
    :field_id => Field.first(:name => "field1").id
end

def add_item_data(item_type, field)
  item = Item.create :item_type_id => item_type.id
  value = ItemDataValue.create :value => "FieldValue"
  ItemData.create :item_id => item.id,
    :field_id => field.id, :value_id => value.id
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
    add_fields(@it)
    bfm = add_base_field_mapping(@it)
    @it.base_field_mappings.size.should == 1
    @it.base_field_mappings.first.should == bfm
  end
  
  it 'has base-fields' do
    add_fields(@it)
    bfm = add_base_field_mapping(@it)
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
end

describe Field do
  before(:each) do
    itemdata = ItemType.create(:name => "foo")
    @f1, _, @itf1, _ = add_fields(itemdata)
    @id = add_item_data(itemdata, @f1)
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
end