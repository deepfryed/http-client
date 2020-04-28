# -*- encoding: utf-8 -*-
# stub: http-client 0.6.1 ruby lib

Gem::Specification.new do |s|
  s.name = "http-client".freeze
  s.version = "0.6.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Bharanee Rathna".freeze]
  s.date = "2020-04-28"
  s.description = "Light weight wrapper around Net::HTTP".freeze
  s.email = ["deepfryed@gmail.com".freeze]
  s.files = ["CHANGELOG".freeze, "README.md".freeze, "lib/http-client.rb".freeze, "lib/http/client.rb".freeze, "test/helper.rb".freeze, "test/server.rb".freeze, "test/test_request.rb".freeze]
  s.homepage = "http://github.com/deepfryed/http-client".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.1".freeze
  s.summary = "A client wrapper around Net::HTTP".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<mime-types>.freeze, ["~> 3.0", ">= 3.0"])
    s.add_runtime_dependency(%q<http-cookie>.freeze, ["~> 1.0", ">= 1.0"])
    s.add_development_dependency(%q<rake>.freeze, ["~> 12.0", ">= 12.0"])
    s.add_development_dependency(%q<minitest-reporters>.freeze, ["~> 1.0", "> 1.0"])
  else
    s.add_dependency(%q<mime-types>.freeze, ["~> 3.0", ">= 3.0"])
    s.add_dependency(%q<http-cookie>.freeze, ["~> 1.0", ">= 1.0"])
    s.add_dependency(%q<rake>.freeze, ["~> 12.0", ">= 12.0"])
    s.add_dependency(%q<minitest-reporters>.freeze, ["~> 1.0", "> 1.0"])
  end
end
