# frozen_string_literal: true

require 'bundler/setup'
require 'webmock/rspec'
require 'my_api_client'

Dir[File.expand_path('spec/dummy_app/**/*.rb')].each do |f|
  puts f
  require f
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
