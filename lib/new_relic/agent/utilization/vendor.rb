# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require 'net/http'

module NewRelic
  module Agent
    module Utilization
      class Vendor
        class << self
          def vendor_name vendor_name = nil
            vendor_name ? @vendor_name = vendor_name.freeze : @vendor_name
          end

          def endpoint endpoint = nil
            endpoint ? @endpoint = URI(endpoint) : @endpoint
          end

          def headers headers = nil
            headers ? @headers = headers.freeze : @headers
          end

          def keys keys = nil
            keys ? @keys = keys.freeze : @keys
          end
        end

        def initialize
          @metadata = {}
        end

        [:vendor_name, :endpoint, :headers, :keys].each do |method_name|
          define_method(method_name) { self.class.send(method_name) }
        end

        SUCCESS = '200'.freeze

        def detect
          response = request_metadata
          if response.code == SUCCESS
            process_response prepare_response(response)
          else
            false
          end
        rescue => e
          NewRelic::Agent.logger.error "Unexpected error obtaining utilization data for #{vendor_name}", e
          record_supportability_metric
          false
        end

        def to_collector_hash
          {
            vendor_name => @metadata
          }
        end

        private

        def request_metadata
          response = nil
          Net::HTTP.start endpoint.host, endpoint.port do |http|
            req = Net::HTTP::Get.new endpoint, headers
            response = http.request req
          end
          response
        end

        def prepare_response response
          JSON.parse response.body
        end

        def process_response response
          keys.each do |key|
            normalized = normalize response[key]
            if normalized
              @metadata[key] = normalized
            else
              @metadata.clear
              record_supportability_metric
              return false
            end
          end
          true
        end

        def normalize value
          return unless String === value
          value.force_encoding Encoding::UTF_8
          value.strip!

          return unless valid_length? value
          return unless valid_chars? value

          value
        end

        def valid_length? value
          if value.bytesize <= 255
            true
          else
            NewRelic::Agent.logger.warn "Found invalid length value while detecting: #{vendor_name}"
            false
          end
        end

        VALID_CHARS = /^[0-9a-zA-Z_ .\/-]$/

        def valid_chars? value
          value.each_char do |ch|
            next if ch =~ VALID_CHARS
            code_point = ch[0].ord # this works in Ruby 1.8.7 - 2.1.2
            next if code_point >= 0x80

            NewRelic::Agent.logger.warn "Found invalid character while detecting: #{vendor_name}"
            return false # it's in neither set of valid characters
          end
          true
        end

        def record_supportability_metric
          NewRelic::Agent.increment_metric "Supportability/utilization/#{vendor_name}/error"
        end
      end
    end
  end
end
