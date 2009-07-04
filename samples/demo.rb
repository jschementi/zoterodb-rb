#!/usr/bin/env ruby

$:.unshift "#{File.dirname(__FILE__)}/../lib/"
require 'zoterodb'
include ZoteroDB::Models

$full_path = File.expand_path(File.dirname(__FILE__))
$dbfile = "#{$full_path}/db/development.db"
RAILS_ROOT = "#{$full_path}/../../../../"

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
      value = if field.field_type == FieldType::Url 
        "http://foo.com"
      elsif field.field_type == FieldType::Location
        "Garden City, NY"
      elsif field.field_type == FieldType::Range
        "1-10"
      elsif field.field_type == FieldType::Date
        "2009-04-19"
      elsif field.field_type == FieldType::Name
        $names[rand($names.size)]
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

def render_item(i, file)
  output file, "    <div style='border-left: 10px solid lightgray; padding-left: 10px'>\n"
  output file, "      <table>\n"
  i.item_type.fields.each do |f|
    begin
      output file, "        <tr><td><b>#{f.display_name}</b></td><td> #{i.send(f.name)}</td></tr>\n"
    rescue
    end
  end
  i.item_type.item_type_creator_types.each do |itct|
    name = itct.creator_type.name
    output file, "        <tr><td><b>#{name}</b></td><td>#{
      [i[name]].flatten.map do |ic| 
        ic.creator.creator_data.full_name
      end.join(" | ")
    }</td></tr>\n"
  end
  output file, "      </table>\n"
  output file, "    </div>\n"
end

def format_items(f, style)
  puts "Formatting items ..."
  [Style.find(style)].compact.each do |s|
    output f, "  <h1>#{s.id.upcase}</h1>\n"
    Item.all.sort{|x,y| x.item_type.name <=> y.item_type.name}.each do |i|
      output f, "    <h2>#{i.item_type.display_name}</h2>\n"
      render_item(i, f)
      output f, "    <div style='border-left: 10px solid lightgray; padding-left: 10px'>\n"
      [:bibliography, :note].each do |t|
        txt = s.format(i, t, :html)
        txt = txt.strip == "<div></div>" ? '<div><em>No format</em></div>' : txt
        output f, "      <h3>#{t}</h3>\n      #{txt}"
      end
      output f, "    </div>\n"
    end
    output f, "<hr />\n"
  end
end

def output(f, text)
  print text
  f.print text if f
end

$actions = {
  :init => lambda { start },
  :test => lambda do
    ['mla', 'apa', 'ieee'].each do |style|
      f = File.open(File.dirname(__FILE__) + "/#{style}-demo.html", 'w') if $actions[:output?][]
      output f, "<html>\n  <head>\n    <title>#{style.upcase}</title>\n  </head>\n  <body>\n"
      format_items(f, style)
      output f, "  </body>\n</html>\n"
      f.close if f
    end
  end,
  :rebuild => lambda do
    if $actions[:rebuild?][]
      rebuild_database
      copy_database
    end
  end,
  :output?  => lambda { return ARGV.include?('output') },
  :rebuild? => lambda { return ARGV.include?('rebuild') },
  :generate => lambda { return generate_items if $actions[:rebuild?][] }
}

if __FILE__ == $0
  $actions[:rebuild][] 
  $actions[:init][]
  $actions[:generate][] 
  $actions[:test][]
end
