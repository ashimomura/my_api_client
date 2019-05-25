# frozen_string_literal: true

require 'dummy_app/api_clients/application_api_client'

class ExampleApiClient < ApplicationApiClient
  endpoint 'https://example.com'
  request_timeout 2.seconds

  retry_on MyApiClient::ApiLimitError, wait: 10.seconds, attempts: 2

  error_handling json: { '$.errors.code': 10..19 }, with: :my_error_handling
  error_handling json: { '$.errors.code': 20 }, raise: MyApiClient::ApiLimitError
  error_handling json: { '$.errors.message': /Sorry/ }, raise: MyApiClient::ServerError

  attr_reader :access_token

  def initialize(access_token)
    @access_token = access_token
  end

  # POST https://example.com/users
  #
  # @param name [String] Username which want to create
  # @return [MyApiClient::Params::Response] HTTP response parameter
  def create_user(name)
    post 'users', headers: headers, body: { name: name }
  end

  # GET https://example.com/users/1
  #
  # @param user_id [Integer] User ID which want to read
  # @return [MyApiClient::Params::Response] HTTP response parameter
  def read_user(user_id)
    get "users/#{user_id}", headers: headers
  end

  # PATCH https://example.com/users/1
  #
  # @param user_id [Integer] User ID which want to read
  # @param name [String] Username which want to be updated
  # @return [MyApiClient::Params::Response] HTTP response parameter
  def update_user(user_id, name)
    patch "users/#{user_id}", headers: headers, body: { name: name }
  end

  # DELETE https://example.com/users/1
  #
  # @param user_id [Integer] User ID which want to delete
  # @return [MyApiClient::Params::Response] HTTP response parameter
  def delete_user(user_id)
    delete "users/#{user_id}", headers: headers
  end

  private

  # Generate common request headers
  #
  # @return [Hash] Request headers
  def headers
    {
      'Content-Type': 'application/json;charset=UTF-8',
      'Authorization': "Bearer #{access_token}",
    }
  end

  # Dump a response body
  #
  # @param params [MyApiClient::Params::Params] HTTP req and res params
  # @param logger [MyApiClient::Logger] Logger for a request processing
  def my_error_handling(params, logger)
    logger.warn "Response Body: #{params.response.body.inspect}"
    raise MyApiClient::ClientError, params
  end
end
