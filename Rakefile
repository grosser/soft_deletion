require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'bump/tasks'

task default: :spec

RSpec::Core::RakeTask.new(:spec)

desc "Bundle all gemfiles"
task :bundle_all do
  Bundler.with_original_env do
    system("which -s matching_bundle") || abort("gem install matching_bundle")
    Dir["gemfiles/*.gemfile"].each do |gemfile|
      sh "BUNDLE_GEMFILE=#{gemfile} matching_bundle"
    end
  end
end
