# frozen_string_literal: true

module MyApiClient
  module ErrorHandling
    extend ActiveSupport::Concern

    class_methods do
      # Description of .error_handling
      #
      # @param status_code [String, Range, Integer, Regexp] default: nil
      # @param json [Hash] default: nil
      # @param with [Symbol] default: nil
      # @param raise [MyApiClient::Error] default: MyApiClient::Error
      # @param block [Proc] describe_block_here
      def error_handling(status_code: nil, json: nil, with: nil, raise: MyApiClient::Error)
        temp = error_handlers.dup
        temp << lambda { |response|
          if match?(status_code, response.status) && match_all?(json, response.body)
            if block_given?
              ->(params, logger) { yield params, logger }
            elsif with
              with
            else
              ->(params, _logger) { raise raise, params }
            end
          end
        }
        self.error_handlers = temp
      end

      private

      def match?(operator, target)
        return true if operator.nil?

        case operator
        when String, Integer
          operator == target
        when Range
          operator.include?(target)
        when Regexp
          operator =~ target.to_s
        else
          false
        end
      end

      def match_all?(json, response_body)
        return true if json.nil?

        json.all? do |path, operator|
          target = JsonPath.new(path.to_s).first(response_body)
          match?(operator, target)
        end
      end
    end

    # The error handlers defined later takes precedence
    #
    # @param params [Sawyer::Response] describe_params_here
    # @return [Proc, Symbol, nil] description_of_returned_object
    def error_handling(response)
      error_handlers.reverse_each do |error_handler|
        result = error_handler.call(response)
        return result unless result.nil?
      end
      nil
    end
  end
end
