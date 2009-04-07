#!/usr/bin/env ruby

$:.unshift "#{File.dirname(__FILE__)}/../lib/"
require 'zoterodb'
include ZoteroDB::Models

$full_path = File.expand_path(File.dirname(__FILE__))
RAILS_ROOT = "#{$full_path}/../../../../"
$dbfile = "#{$full_path}/db/development.db"

def rebuild_database
  puts "rebuilding database"
  FileUtils.cd RAILS_ROOT do
    `rake dm:migrate:down`
    `rake dm:migrate:up`
  end
end

def copy_database
  puts "copying database"
  require 'fileutils'
  FileUtils.cp "#{RAILS_ROOT}/db/development.db", $dbfile
end

def start
  puts "Starting ..."
  DataMapper.setup :default, "sqlite3://#{$dbfile}"

  $:.unshift "#{RAILS_ROOT}/app/models"
  $:.unshift "#{RAILS_ROOT}/vendor/plugins/rails-authorization-plugin/lib"
  
  require 'authorization'
  require 'publishare/object_roles_table'

  require 'field'
  require 'field_type'
  require 'style'

  $names = [
    "Jimmy Schementi",
    "John Doe",
    "Sally Bar",
    "Ivan Tolive",
    "Ronald Silvia",
    "Apolo Ono",
    "Jane Don"
  ]
end

def generate_items
  puts "Generating items ...\n"
  ItemType.all.each do |it|
    i = it.items.create
    puts("-" * 40)
    puts "Creating \"#{it.name}\""
    it.fields.each do |field|
      value = if field.field_type == FieldType::Url then "http://foo.com"
      elsif field.field_type == FieldType::Location then "Garden City, NY"
      elsif field.field_type == FieldType::Range    then "1-10"
      elsif field.field_type == FieldType::Date     then "2009-04-19"
      elsif field.field_type == FieldType::Name     then "James Schementi"
      else
        field.name
      end
      i.send("#{field.name}=", value)
      puts "#{field.name} = #{value}"
    end
    it.creator_types
    it.item_type_creator_types.each do |itct|
      ct = itct.creator_type
      (rand(3) + 1).times do
        n = $names[rand($names.size)]
        i[ct.name] = lambda do |name|
          sn = name.split(" ")
          {:last => sn.last, :first => sn.first}
        end[n]
        puts "#{ct.name} = #{n}"
      end
    end
  end
end

def format_items
  puts "Formatting items ...\n"
  text = ''
  Style.all.each do |s|
    puts text = "<h1>#{s.id.upcase}</h1>"
    Item.all.each do |i|
      [:bibliography, :note].each do |t|
        text = <<-EOS
<h2>#{i.item_type.name} (#{s.id} #{t})</h2>
#{s.format(i, t, :html)}
        EOS
        puts text
      end
    end
    puts text = "<hr />"
  end
  #puts text
end

if __FILE__ == $0
  #rebuild_database
  #copy_database
  start
  #generate_items
  format_items
end