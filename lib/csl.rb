begin
  require 'citeproc'
rescue MissingSourceFile => e
  $:.unshift File.dirname(__FILE__) + '/../etc/xbiblio/citeproc-rb/lib/'
  require 'citeproc'
end

require 'models'
require 'map'

module ZoteroDB
  
  class Formatting
    #
    # Convert item(s) into a CSL citation(s)
    #
    def self.items_to_citations(items)
      csls = [items].flatten.inject([]) do |ary, item|
        csl = nil
        csl = CSL::Citation.new
        csl.type = TYPE_MAP[item.item_type.name] || item.item_type.name

        # look at the base types, as the real types can just be a facade
        item.item_type.fields.each do |f|

          f.name = '_repository' if f.name == 'repository'
          f.name = '_type' if f.name == 'type'

          # Use the field_map table to find a name for the field that the
          # citation can use. If that field isn't in the table, just use
          # it's current name. Note that one item field can set multiple
          # citation fields.
          csl_field = FIELD_MAP[f.name]
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

        ary << csl
      end
      items.kind_of?(Array) ? csls : csls.first
    end

    #
    # Format item(s) in a CSL style
    #
    def self.format(items, style, type = :bibliography)
      type = :citation if type == :note
      count = 0

      input_filter = CSL::CslInputFilter.new
      input_filter.citations = 
        [items_to_citations(items)].flatten.inject({}) do |csls, citation|
          csls[count += 1] = citation
          csls
        end

      style = Citeproc::CslParser.
        new(File.dirname(__FILE__) + "/../../xbiblio/citeproc-rb/data/styles/#{style}.csl").style

      processor = Citeproc::CslProcessor.new
      formatter = Citeproc::BaseFormatter.new

      nodes = processor.send("process_#{type}", input_filter, style, nil)
      formatter.format(nodes)
    end
  end
  
end