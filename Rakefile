$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'date'
require 'pathname'
require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rubygems/package_task'
require 'http/client'

$rootdir = Pathname.new(__FILE__).dirname
$gemspec = Gem::Specification.new do |s|
  s.name              = 'http-client'
  s.version           = HTTP::Client::VERSION
  s.date              = Date.today
  s.authors           = ['Bharanee Rathna']
  s.email             = ['deepfryed@gmail.com']
  s.summary           = 'A client wrapper around Net::HTTP'
  s.description       = 'Light weight wrapper around Net::HTTP'
  s.homepage          = 'http://github.com/deepfryed/http-client'
  s.files             = Dir['{test,lib}/**/*.rb'] + %w(README.md CHANGELOG)
  s.require_paths     = %w(lib)

  s.add_dependency('mime-types', '~> 3.1')
  s.add_dependency('http-cookie', '~> 1.0.2')
  s.add_development_dependency('rake', '~> 11.1.2')
  s.add_development_dependency('minitest-reporters', '~> 1.1.9')
end

desc 'Generate gemspec'
task :gemspec do
  $gemspec.date = Date.today
  File.open('http-client.gemspec', 'w') {|fh| fh.write($gemspec.to_ruby)}
end

Gem::PackageTask.new($gemspec) do |pkg|
end

Rake::TestTask.new(:test) do |test|
  test.libs    << 'lib' << 'test'
  test.pattern  = 'test/**/test_*.rb'
  test.verbose  = true
  test.warning  = false # YUCK, but removes circular dependency noise due to minitest :(
end

task default: :test

desc 'tag release and build gem'
task :release => [:test, :gemspec] do
  system("git tag -m 'version #{$gemspec.version}' v#{$gemspec.version}") or raise "failed to tag release"
  system("rake package")
end
