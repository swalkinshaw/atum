require 'rack/utils'

module Atum
  module Core
    class Paginator
      def initialize(request, initial_response, options)
        @request = request
        @options = options
        @initial_response = initial_response
      end

      def enumerator
        response = @initial_response

        Enumerator.new do |yielder|
          loop do
            items = @request.unenvelope(response.body)
            items.each { |item| yielder << item }

            break unless response.paginated?

            pagination_query_string = URI.parse(response.links['next']).query

            new_options = @options.dup
            new_options[:query] = @options.fetch(:query, {}).merge(
              Rack::Utils.parse_nested_query(pagination_query_string)
            )

            response = Response.new(@request.make_request(new_options))
          end
        end.lazy
      end
    end
  end
end
