# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "../../../../async/container/generic"
require "metrics/provider"

Metrics::Provider(Async::Container::Generic) do
	ASYNC_CONTAINER_GENERIC_HEALTH_CHECK_FAILED = Metrics.metric("async.container.generic.health_check_failed", :counter, description: "The number of health checks that failed.")
	
	protected def health_check_failed!(child, age_clock, health_check_timeout)
		ASYNC_CONTAINER_GENERIC_HEALTH_CHECK_FAILED.emit(1)
		
		super
	end
end
