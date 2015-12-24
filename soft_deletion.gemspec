name = "soft_deletion"
require "./lib/#{name}/version"

Gem::Specification.new name, SoftDeletion::VERSION do |s|
  s.summary = "Explicit soft deletion for ActiveRecord via deleted_at and default scope."
  s.authors = ["Zendesk"]
  s.email = "michael@grosser.it"
  s.homepage = "https://github.com/grosser/#{name}"
  s.files = `git ls-files lib Readme.md`.split("\n")
  s.license = "MIT"
  s.required_ruby_version = '>= 2.0.0'
  s.add_runtime_dependency 'activerecord', '>= 3.2.0', '< 5.1.0'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'rspec', '~> 2.0'
  s.add_development_dependency 'database_cleaner', '>= 1.5.1'
  s.add_development_dependency 'bump'
  s.add_development_dependency 'wwtd'
end
