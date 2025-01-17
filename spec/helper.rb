require 'simplecov'
require 'simplecov-lcov'

SimpleCov::Formatter::LcovFormatter.config do |c|
  c.report_with_single_file = true
  c.single_report_path = 'coverage/lcov.info'
end
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(
  [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter
  ]
)

SimpleCov.start do
  add_filter '/spec/'
end

require 'logger'
require 'rspec'

require 'action_mailer'
require 'active_record'
require 'rails'

require 'delayed_job'
require 'delayed/backend/shared_spec'

if ENV['DEBUG_LOGS']
  Delayed::Worker.logger = Logger.new(STDOUT)
else
  require 'tempfile'

  tf = Tempfile.new('dj.log')
  Delayed::Worker.logger = Logger.new(tf.path)
  tf.unlink
end
ENV['RAILS_ENV'] = 'test'

FakeApp = Class.new(Rails::Application)
FakeApp.config.eager_load = false

Delayed::Worker.backend = :test

# Add this directory so the ActiveSupport autoloading works
ActiveSupport::Dependencies.autoload_paths << File.dirname(__FILE__)

# Used to test interactions between DJ and an ORM
ActiveRecord::Base.establish_connection :adapter => 'sqlite3', :database => ':memory:'
ActiveRecord::Base.logger = Delayed::Worker.logger
ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define do
  create_table :stories, :primary_key => :story_id, :force => true do |table|
    table.string :text
    table.boolean :scoped, :default => true
  end
end

class Story < ActiveRecord::Base
  self.primary_key = 'story_id'
  def tell
    text
  end

  def whatever(n, _)
    tell * n
  end
  default_scope { where(:scoped => true) }

  handle_asynchronously :whatever
end

FakeApp.initialize!

RSpec.configure do |config|
  config.after(:each) do
    Delayed::Worker.reset
  end

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
