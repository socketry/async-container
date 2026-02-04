#!/usr/bin/env async-service
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async"
require "async/service/managed_service"
require "async/service/managed_environment"

class SleepService < Async::Service::ManagedService
	def run(instance, evaluator)
		Async do |task|
			while true
				Console.info(self, "Sleeping for 5 seconds...")
				task.defer_stop do
					sleep 5
				end
			end
		ensure
			Console.info(self, "Exiting sleep service...")
		end
	end
end

module SleepEnvironment
	include Async::Service::ManagedEnvironment
	
	def service_class
		SleepService
	end
end

service "sleep" do
	include SleepEnvironment
	
	count 1
end
