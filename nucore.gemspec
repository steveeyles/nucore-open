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
  s.add_dependency "protected_attributes"
  s.add_dependency "rails_config", "0.3.3"
  s.add_dependency "devise", "~> 3.5.10"
  s.add_dependency "devise-encryptable", "~> 0.2.0"
  s.add_dependency "devise_ldap_authenticatable", "~> 0.8.5"
  s.add_dependency "rails-observers"
  s.add_dependency "haml", "~> 4.0.5"
  s.add_dependency "rails-observers"
  s.add_dependency "paperclip",        "~> 4.2.0"

end
