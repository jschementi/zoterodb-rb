module ZoteroDB
  VERSION = '0.1'
end

$: << "#{File.dirname(__FILE__)}/lib/"

require 'models'
require 'csl'