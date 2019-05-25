# frozen_string_literal: true

require 'logger'
require 'jsonpath'
require 'active_support'
require 'active_support/core_ext'
require 'sawyer'
require 'my_api_client/version'
require 'my_api_client/config'
require 'my_api_client/error_handling'
require 'my_api_client/exceptions'
require 'my_api_client/logger'
require 'my_api_client/errors'
require 'my_api_client/params/params'
require 'my_api_client/params/request'
require 'my_api_client/request'
require 'my_api_client/base'

if Sawyer::VERSION < '0.8.2'
  module Sawyer
    # NOTE: Old sawyer does not have attribute reader for response body.
    #       But new version sawyer is conflict some gems (e.g. octkit).
    class Response
      attr_reader :body, :env

      alias _original_initialize initialize

      def initialize(agent, res, options = {})
        @body = res.body
        _original_initialize(agent, res, options)
      end
    end
  end
end
