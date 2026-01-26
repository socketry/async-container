#!/usr/bin/env async-service
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require "async"
require "async/service/managed_service"
require "async/service/managed_environment"

class SleepService < Async::Service::ManagedService
	def run(instance, evaluator)
		Async do
			Console.info(self, "Sleeping for 10 seconds...")
			sleep 10
		end
	end
end

module SleepEnvironment
	include Async::Service::ManagedEnvironment
	
	def service_class
		SleepService
	end
	
	def startup_timeout
		9
	end
	
	def health_check_timeout
		4
	end
	
	def prepare!(instance)
		Console.info(self, "Preparing instance #{instance}...")
		instance.status!("Preparing...")
		sleep 8.5
		instance.status!("Finished preparing...")
	end
end

service "sleep" do
	include SleepEnvironment
	
	count 1
end
