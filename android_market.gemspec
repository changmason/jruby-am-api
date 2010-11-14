# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "android_market/version"

Gem::Specification.new do |s|
  s.name        = "android_market"
  s.version     = AndroidMarket::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Mason Chang"]
  s.email       = ["changmason@gmail.com"]
  s.homepage    = "http://rubygems.org/gems/android_market"
  s.summary     = %q{android market api in jruby}
  s.description = %q{a port of android market api from java}

  s.rubyforge_project = "android_market"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
