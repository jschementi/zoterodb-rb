#!/usr/bin/env ruby

$:.unshift "#{File.dirname(__FILE__)}/../lib/"
require 'zoterodb'

include ZoteroDB::Models

db = "sqlite3://#{File.expand_path(File.dirname(__FILE__))}/db/zotero.sqlite"
DataMapper.setup :default, db

puts ZoteroDB::Formatting.format(
       ZoteroDB::Models::Item.all, :mla, :bibliography, :base
     )