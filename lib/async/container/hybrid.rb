# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.
# Copyright, 2022, by Anton Sozontov.

require_relative "forked"
require_relative "threaded"

module Async
	module Container
		# Provides a hybrid multi-process multi-thread container.
		class Hybrid < Forked
			# Run multiple instances of the same block in the container.
			# @parameter count [Integer] The number of instances to start.
			# @parameter forks [Integer] The number of processes to fork.
			# @parameter threads [Integer] the number of threads to start.
			# @parameter health_check_timeout [Numeric] The timeout for health checks, in seconds. Passed into the child {Threaded} containers.
			def run(count: nil, forks: nil, threads: nil, health_check_timeout: nil, **options, &block)
				processor_count = Container.processor_count
				count ||= processor_count ** 2
				forks ||= [processor_count, count].min
				threads ||= (count / forks).ceil
				
				forks.times do
					self.spawn(**options) do |instance|
						container = Threaded.new
						
						# Link each inner thread worker to this fork, so the thread instance can reach
						# the durable process num via `instance.parent` / `instance.context`.
						container.run(count: threads, health_check_timeout: health_check_timeout, **options) do |worker|
							worker.parent = instance
							block.call(worker)
						end
						
						container.wait_until_ready
						instance.ready!
						
						begin
							container.wait
						rescue Interrupt
							# Gracefully interrupt child threads; parent process handles escalation.
							container.interrupt
							retry
						end
					ensure
						container.stop(false)
					end
				end
				
				return self
			end
		end
	end
end
