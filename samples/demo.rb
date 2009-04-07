#!/usr/bin/env ruby

$:.unshift "#{File.dirname(__FILE__)}/../lib/"
require 'zoterodb'
include ZoteroDB::Models

$full_path = File.expand_path(File.dirname(__FILE__))
$rails_root = "#{$full_path}/../../../../"
$dbfile = "#{$full_path}/db/development.db"

def rebuild_database
  puts "rebuilding database"
  FileUtils.cd $rails_root do
    `rake dm:migrate:down`
    `rake dm:migrate:up`
  end
end

def copy_database
  puts "copying database"
  require 'fileutils'
  FileUtils.cp "#{$rails_root}/db/development.db", $dbfile
end

def start
  puts "Starting ..."
  DataMapper.setup :default, "sqlite3://#{$dbfile}"

  $:.unshift "#{$rails_root}/app/models"
  $:.unshift "#{$rails_root}/vendor/plugins/rails-authorization-plugin/lib"
  
  require 'authorization'
  require 'publishare/object_roles_table'

  require 'field'
  require 'field_type'

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
  Item.all.each do |i|
    puts "#{i.item_type.name} => #{ZoteroDB::Formatting.format(
      i, :mla, :bibliography, :html
    )}"
  end
end

if __FILE__ == $0
  rebuild_database
  copy_database
  start
  generate_items
  format_items
end