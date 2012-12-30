require 'bundler/setup'
require 'appraisal'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'bump/tasks'

task :default do
  sh "bundle exec rake appraisal:install && bundle exec rake appraisal spec"
end

RSpec::Core::RakeTask.new(:spec)
