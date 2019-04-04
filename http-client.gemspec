# -*- encoding: utf-8 -*-
# stub: http-client 0.6.0 ruby lib

Gem::Specification.new do |s|
  s.name = "http-client"
  s.version = "0.6.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Bharanee Rathna"]
  s.date = "2019-04-05"
  s.description = "Light weight wrapper around Net::HTTP"
  s.email = ["deepfryed@gmail.com"]
  s.files = ["CHANGELOG", "README.md", "lib/http-client.rb", "lib/http/client.rb", "test/helper.rb", "test/server.rb", "test/test_request.rb"]
  s.homepage = "http://github.com/deepfryed/http-client"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.5.1"
  s.summary = "A client wrapper around Net::HTTP"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<mime-types>, [">= 3.0", "~> 3.0"])
      s.add_runtime_dependency(%q<http-cookie>, [">= 1.0", "~> 1.0"])
      s.add_development_dependency(%q<rake>, [">= 11.0", "~> 11.0"])
      s.add_development_dependency(%q<minitest-reporters>, ["> 1.0", "~> 1.0"])
    else
      s.add_dependency(%q<mime-types>, [">= 3.0", "~> 3.0"])
      s.add_dependency(%q<http-cookie>, [">= 1.0", "~> 1.0"])
      s.add_dependency(%q<rake>, [">= 11.0", "~> 11.0"])
      s.add_dependency(%q<minitest-reporters>, ["> 1.0", "~> 1.0"])
    end
  else
    s.add_dependency(%q<mime-types>, [">= 3.0", "~> 3.0"])
    s.add_dependency(%q<http-cookie>, [">= 1.0", "~> 1.0"])
    s.add_dependency(%q<rake>, [">= 11.0", "~> 11.0"])
    s.add_dependency(%q<minitest-reporters>, ["> 1.0", "~> 1.0"])
  end
end
