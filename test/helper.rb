require 'bundler/setup'

require 'http-client'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'

require  'server'
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

