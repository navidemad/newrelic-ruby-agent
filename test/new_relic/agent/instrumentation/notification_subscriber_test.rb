# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/newrelic-ruby-agent/blob/main/LICENSE for complete details.
# frozen_string_literal: true

require_relative '../../../test_helper'
require 'new_relic/agent/instrumentation/notifications_subscriber'

if defined?(ActiveSupport)
  require_relative 'rails/notifications_subscriber'
else
  puts "Skipping tests in #{__FILE__} because Active Support is unavailable"
end