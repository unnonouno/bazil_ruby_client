require 'bundler'
Bundler::GemHelper.install_tasks

require 'rubygems'
require 'rake'

require 'rspec/core'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rspec_opts = ['--color --backtrace']
end

task :default => [:spec]
