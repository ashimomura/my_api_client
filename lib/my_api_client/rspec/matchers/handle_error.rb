# frozen_string_literal: true

require 'rspec/expectations'
require 'webmock/rspec'

RSpec::Matchers.define :handle_error do |expected_error_handling|
  include MyApiClient::MatcherHelper

  match do |api_request|
    begin
      api_request.call
    rescue StandardError => e
      if expected_error_handling[:raise]
        e.is_a? expected_error_handling[:raise]
      else
        true
      end
    else
      false
    end
  end

  chain :when_receive do |api_response|
    disable_logging
    response = dummy_response(
      status: api_response[:status_code] || 200,
      headers: api_response[:headers] || {},
      body: api_response[:body] || nil
    )
    sawyer = instance_double(Sawyer::Agent, call: response)
    allow(Sawyer::Agent).to receive(:new).and_return(sawyer)
  end

  supports_block_expectations
end
