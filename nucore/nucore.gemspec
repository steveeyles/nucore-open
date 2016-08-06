$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "nucore/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "nucore"
  s.version     = Nucore::VERSION
  s.authors     = ["Table XI"]
  s.email       = ["devs@tablexi.com"]
  s.homepage    = "http://www.github.com/tablexi/nucore-open"
  s.summary     = "Summary of NUcore."
  s.description = "Description of NUcore."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["spec/**/*"]

  s.add_dependency "rails", "~> 4.2.7"

end
