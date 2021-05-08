# frozen_string_literal: true

# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'async'

require 'etc'

require_relative 'group'
require_relative 'keyed'
require_relative 'statistics'

module Async
	module Container
		# An environment variable key to override {.processor_count}.
		ASYNC_CONTAINER_PROCESSOR_COUNT = 'ASYNC_CONTAINER_PROCESSOR_COUNT'
		
		# The processor count which may be used for the default number of container threads/processes. You can override the value provided by the system by specifying the `ASYNC_CONTAINER_PROCESSOR_COUNT` environment variable.
		# @returns [Integer] The number of hardware processors which can run threads/processes simultaneously.
		# @raises [RuntimeError] If the process count is invalid.
		def self.processor_count(env = ENV)
			count = env.fetch(ASYNC_CONTAINER_PROCESSOR_COUNT) do
				Etc.nprocessors rescue 1
			end.to_i
			
			if count < 1
				raise RuntimeError, "Invalid processor count #{count}!"
			end
			
			return count
		end
		
		# A base class for implementing containers.
		class Generic
			def self.run(*arguments, **options, &block)
				self.new.run(*arguments, **options, &block)
			end
			
			UNNAMED = "Unnamed"
			
			def initialize(**options)
				@group = Group.new
				@running = true
				
				@state = {}
				
				@statistics = Statistics.new
				@keyed = {}
			end
			
			attr :state
			
			# A human readable representation of the container.
			# @returns [String]
			def to_s
				"#{self.class} with #{@statistics.spawns} spawns and #{@statistics.failures} failures."
			end
			
			# Look up a child process by key.
			# A key could be a symbol, a file path, or something else which the child instance represents.
			def [] key
				@keyed[key]&.value
			end
			
			# Statistics relating to the behavior of children instances.
			# @attribute [Statistics]
			attr :statistics
			
			# Whether any failures have occurred within the container.
			# @returns [Boolean]
			def failed?
				@statistics.failed?
			end
			
			# Whether the container has running children instances.
			def running?
				@group.running?
			end
			
			# Sleep until some state change occurs.
			# @parameter duration [Numeric] the maximum amount of time to sleep for.
			def sleep(duration = nil)
				@group.sleep(duration)
			end
			
			# Wait until all spawned tasks are completed.
			def wait
				@group.wait
			end
			
			# Returns true if all children instances have the specified status flag set.
			# e.g. `:ready`.
			# This state is updated by the process readiness protocol mechanism. See {Notify::Client} for more details.
			# @returns [Boolean]
			def status?(flag)
				# This also returns true if all processes have exited/failed:
				@state.all?{|_, state| state[flag]}
			end
			
			# Wait until all the children instances have indicated that they are ready.
			# @returns [Boolean] The children all became ready.
			def wait_until_ready
				while true
					Console.logger.debug(self) do |buffer|
						buffer.puts "Waiting for ready:"
						@state.each do |child, state|
							buffer.puts "\t#{child.class}: #{state.inspect}"
						end
					end
					
					self.sleep
					
					if self.status?(:ready)
						return true
					end
				end
			end
			
			# Stop the children instances.
			# @parameter timeout [Boolean | Numeric] Whether to stop gracefully, or a specific timeout.
			def stop(timeout = true)
				@running = false
				@group.stop(timeout)
				
				if @group.running?
					Console.logger.warn(self) {"Group is still running after stopping it!"}
				end
			ensure
				@running = true
			end
			
			# Spawn a child instance into the container.
			# @parameter name [String] The name of the child instance.
			# @parameter restart [Boolean] Whether to restart the child instance if it fails.
			# @parameter key [Symbol] A key used for reloading child instances.
			def spawn(name: nil, restart: false, key: nil, &block)
				name ||= UNNAMED
				
				if mark?(key)
					Console.logger.debug(self) {"Reusing existing child for #{key}: #{name}"}
					return false
				end
				
				@statistics.spawn!
				
				fiber do
					while @running
						child = self.start(name, &block)
						
						state = insert(key, child)
						
						begin
							status = @group.wait_for(child) do |message|
								state.update(message)
							end
						ensure
							delete(key, child)
						end
						
						if status.success?
							Console.logger.info(self) {"#{child} exited with #{status}"}
						else
							@statistics.failure!
							Console.logger.error(self) {status}
						end
						
						if restart
							@statistics.restart!
						else
							break
						end
					end
				# ensure
				# 	Console.logger.error(self) {$!} if $!
				end.resume
				
				return true
			end
			
			# Run multiple instances of the same block in the container.
			# @parameter count [Integer] The number of instances to start.
			def run(count: Container.processor_count, **options, &block)
				count.times do
					spawn(**options, &block)
				end
				
				return self
			end
			
			# @deprecated Please use {spawn} or {run} instead.
			def async(**options, &block)
				spawn(**options) do |instance|
					Async::Reactor.run(instance, &block)
				end
			end
			
			# Reload the container's keyed instances.
			def reload
				@keyed.each_value(&:clear!)
				
				yield
				
				dirty = false
				
				@keyed.delete_if do |key, value|
					value.stop? && (dirty = true)
				end
				
				return dirty
			end
			
			# Mark the container's keyed instance which ensures that it won't be discarded.
			def mark?(key)
				if key
					if value = @keyed[key]
						value.mark!
						
						return true
					end
				end
				
				return false
			end
			
			# Whether a child instance exists for the given key.
			def key?(key)
				if key
					@keyed.key?(key)
				end
			end
			
			protected
			
			# Register the child (value) as running.
			def insert(key, child)
				if key
					@keyed[key] = Keyed.new(key, child)
				end
				
				state = {}
				
				@state[child] = state
				
				return state
			end
			
			# Clear the child (value) as running.
			def delete(key, child)
				if key
					@keyed.delete(key)
				end
				
				@state.delete(child)
			end
			
			private
			
			if Fiber.respond_to?(:blocking?)
				def fiber(&block)
					Fiber.new(blocking: true, &block)
				end
			else
				def fiber(&block)
					Fiber.new(&block)
				end
			end
		end
	end
end
