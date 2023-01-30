require 'bundler/setup'
require 'bundler/gem_tasks'

require 'bump/tasks'
Bump.replace_in_default = Dir["gemfiles/*.lock"]

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task default: :spec

desc "Bundle all gemfiles"
task :bundle_all do
  Bundler.with_original_env do
    Dir["gemfiles/*.gemfile"].each do |gemfile|
      sh "BUNDLE_GEMFILE=#{gemfile} bundle"
    end
  end
end
