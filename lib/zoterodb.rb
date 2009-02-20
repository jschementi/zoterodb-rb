module ZoteroDB
  VERSION = '0.1.0'
end

$: << "#{File.dirname(__FILE__)}/zoterodb/"

require 'models'
require 'csl'