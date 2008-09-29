require 'rubygems'
require 'rake/rdoctask'
require 'rake/testtask'
require 'rake/clean'
require 'rcov/rcovtask'

task :default => :test

Rake::RDocTask.new do |rd|
  rd.main = 'RubyDav'
  rd.title = 'RubyDAV Documentation'
  rd.rdoc_dir = 'doc'
  rd.options << '--all'
end

# Test Tasks --------------------------------------

task :test => ["test:unit","test:functional"]

namespace :test do
  Rake::TestTask.new("functional") do |t|
    t.test_files = FileList['test/functional/rubydav_*test.rb']
  end

  Rake::TestTask.new("unit") do |t|
    t.test_files = FileList['test/unit/*_test.rb']
  end
end

Rcov::RcovTask.new do |t|
    t.libs << "test"
    t.test_files = FileList['test/unit/*_test.rb','test/functional/*_test.rb']	
    t.verbose = true
end


