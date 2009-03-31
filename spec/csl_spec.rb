require "#{File.dirname(__FILE__)}/../../../../spec/spec_helper"

def create_blog_post_type
  @blog_post_type ||= ItemType.create :name => "blogPost"

  ["title", "abstractNote", "blogTitle", "websiteType", "date", "url", "accessDate", "language", "shortTitle", "rights", "extra"].each do |name|
    ItemTypeField.create(
      :item_type_id => @blog_post_type.id, 
      :field_id => Field.create(:name => name).id
    )
  end

  ["author", "contributor", "commenter"].each do |name|
    ItemTypeCreatorType.create(
      :item_type_id => @blog_post_type.id,
      :creator_type_id => CreatorType.create(:name => name).id
    )
  end

  @blog_post_type
end

def create_blog_post(creators, fields)
  @blog_post_type ||= create_blog_post_type
  blog_post         = Item.create :item_type_id => @blog_post_type.id
  creators.each { |key, value| blog_post[key] = value          }
  fields.each   { |key, value| blog_post.send "#{key}=", value }
  blog_post
end

describe ZoteroDB::Formatting do
  before(:each) do
    DataMapper.auto_migrate!

    create_blog_post_type
    @creators = {
      :author      => {:last => 'Schementi', :first => 'Jimmy'   },
      :contributor => {:last => 'Cutrone',   :first => 'Felicia' },
      :commenter   => {:last => 'Schementi', :first => 'Joanne'  }
    }
    @fields = {
      :title        => "Blog post title",
      :blogTitle    => "Blog title",
      :websiteType  => 'Website type',
      :date         => '2009-03-01',
      :url          => 'http://foo.com',
      :accessDate   => '2009-03-12'
    }
    @blog_post = create_blog_post @creators, @fields
  end

  it 'converts a item to a citation' do
    citation = ZoteroDB::Formatting.items_to_citations(@blog_post)
    citation.title.to_s.should == @fields[:title]
    citation.URL.to_s.should == @fields[:url]
    citation.type.should == 'post-weblog'
    citation.date_issued.to_s.should == @fields[:date]
    citation.date_accessed.to_s.should == @fields[:accessDate]
    contribs = citation.instance_variable_get(:"@contributors")
    contribs.size.should == 3
    cc = contribs.inject({}){ |cc, c| cc[c.role.to_sym] = c.name; cc }
    @creators.keys.each do |key|
      cc[key].should == "#{@creators[key][:last]}, #{@creators[key][:first]}"
    end
  end
  
  it 'formats a citation in basic text' do
    text = ZoteroDB::Formatting.format(@blog_post, :mla, :bibliography, :base)
    text.should == "Schementi, Jimmy. \"Blog post title\". 1st Mar 2009. 12th Mar 2009.\n"
  end
end