require 'bundler/setup'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
require 'server'
require 'http-client'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

