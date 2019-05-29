# frozen_string_literal: true

require 'my_api_client'
require 'my_api_client/rspec/stub'

RSpec.configure do |config|
  config.include MyApiClient::Stub
end
