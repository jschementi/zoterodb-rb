require 'models'

$:.unshift File.dirname(__FILE__) + '/../xbiblio/citeproc-rb/lib/'
require 'citeproc'

load 'map.rb'

#
# Convert all items into Citations
#

csls = {}
Item.all.each do |item|
  csl = nil
  csl = CSL::Citation.new
  csl.type = $type_map[item.item_type.name] || item.item_type.name

  # look at the base types, as the real types can just be a facade
  item.item_type.fields.each do |f|

    f.name = '_repository' if f.name == 'repository'
    f.name = '_type' if f.name == 'type'

    # Use the field_map table to find a name for the field that the
    # citation can use. If that field isn't in the table, just use
    # it's current name. Note that one item field can set multiple
    # citation fields.
    csl_field = $field_map[f.name]
    base_field_map = item.item_type.base_field_mappings.
      first('field.name' => f.name) unless csl_field
    csl_name = nil
    csl_name ||= base_field_map.base_field.name if base_field_map
    csl_name ||= f.name unless csl_field
    csl_name ||= csl_field

    [csl_name].flatten.compact.each do |v|
      # transform the CSL variable to match what Citeproc calls it
      v = CSL::Citation.transform_variable(v)
      csl.send("#{v}=", item.send(f.name)) if csl.respond_to? v
    end

  end

  # creators are seperate, so add them all to the citation
  item.item_creators.each do |ic|
    csl.add_contributor_name ic.creator.last_name, ic.creator_type.name
  end

  csls[item.item_type.name] = csl
end

#
# Format the citations in MLA
#

input_filter = CSL::CslInputFilter.new
input_filter.citations = csls

style = Citeproc::CslParser.new('../xbiblio/citeproc-rb/data/styles/mla.csl').style

processor = Citeproc::CslProcessor.new
formatter = Citeproc::BaseFormatter.new

nodes = processor.process_bibliography(input_filter, style, nil)
results = formatter.format(nodes)

puts results