# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require_relative "forked"
require_relative "threaded"

module Async
	module Container
		# Represents a container which spawns forked processes that manage threaded children.
		class Hybrid < Generic
			# Initialize the hybrid container.
			# @parameter arguments [Array] Positional arguments for {Generic#initialize}.
			# @parameter options [Hash] Keyword options for {Generic#initialize}.
			def initialize(*arguments, **options)
				super(Forked::Child, *arguments, **options)
			end
			
			# Spawn forked containers, each managing a set of threaded children.
			# @parameter count [Integer | Nil] The total number of threaded children.
			# @parameter forks [Integer | Nil] The number of forked child containers.
			# @parameter threads [Integer | Nil] The number of threads per fork.
			# @parameter health_check_timeout [Numeric | Nil] The timeout for child health checks.
			# @parameter options [Hash] Additional child options.
			# @yields {|instance| ...} The threaded child body.
			# 	@parameter instance [Threaded::Instance] The child-side instance interface.
			# @returns [Hybrid] The hybrid container.
			def run(count: nil, forks: nil, threads: nil, health_check_timeout: nil, **options, &block)
				processor_count = Async::Container.processor_count
				count ||= processor_count ** 2
				forks ||= [processor_count, count].min
				threads ||= (count / forks).ceil
				
				forks.times do
					spawn(**options) do |instance|
						Sync do
							container = Threaded.new
							
							container.run(count: threads, health_check_timeout: health_check_timeout, **options, &block)
							container.wait_until_ready
							
							instance.ready!
							
							begin
								container.wait
							rescue Interrupt
								container.interrupt
								retry
							end
						ensure
							container&.stop(false)
						end
					end
				end
				
				return self
			end
			
			# Whether this container uses multiple processes.
			# @returns [Boolean]
			def self.multiprocess?
				true
			end
		end
	end
end
