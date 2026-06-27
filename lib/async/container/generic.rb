# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.
# Copyright, 2025, by Marc-André Cournoyer.

require "etc"
require "io/wait"
require "async/clock"
require "async/queue"

require_relative "group"
require_relative "keyed"
require_relative "statistics"
require_relative "policy"

module Async
	module Container
		# An environment variable key to override {.processor_count}.
		ASYNC_CONTAINER_PROCESSOR_COUNT = "ASYNC_CONTAINER_PROCESSOR_COUNT"
		
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
			# Run a new container.
			def self.run(...)
				self.new.run(...)
			end
			
			UNNAMED = "Unnamed"
			
			# Initialize the container.
			#
			# @parameter policy [Policy] The policy to use for managing child lifecycle events.
			# @parameter options [Hash] Options passed to the {Group} instance.
			def initialize(policy: Policy::DEFAULT, **options)
				@group = Group.new(**options)
				@stopping = false
				
				@state = {}
				
				@policy = policy
				@statistics = @policy.make_statistics
				@keyed = {}
			end
			
			# @attribute [Group] The group of running children instances.
			attr :group
			
			# @returns [Integer] The number of running children instances.
			def size
				@group.size
			end
			
			# @attribute [Hash(Child, Hash)] The state of each child instance.
			attr :state
			
			# @attribute [Policy] The policy for managing child lifecycle events.
			attr_accessor :policy
			
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
			
			# Whether the container is currently stopping.
			# @returns [Boolean]
			def stopping?
				@stopping
			end
			
			# Sleep until some state change occurs or the specified duration elapses.
			#
			# @parameter duration [Numeric] the maximum amount of time to sleep for.
			def sleep(duration = nil)
				@group.sleep(duration)
			end
			
			# Wait until all spawned tasks are completed.
			def wait
				@group.wait
			end
			
			# Gracefully interrupt all child instances.
			def interrupt
				# We must enter the stopping state before signalling the children. Interrupting a child causes it to drain and exit, but the main run loop will respawn any child that exits while `restart: true` and the container is not stopping (see the `restart && !@stopping` gate in `#run`). Without setting this flag, an interrupted child immediately respawns, so the container never drains and `#wait` never returns.
				#
				# This matters most for `Hybrid` containers: a `SIGINT`/`SIGTERM` delivered to a fork is translated into a call to `#interrupt` on the inner threaded container, which typically runs with `restart: true` (the default for `async-service` managed services). If `#interrupt` did not set this flag, the inner threads would drain, exit, and respawn in a loop, so a single signal would never terminate the fork. Setting `@stopping = true` here makes `#interrupt` behave as the start of a graceful shutdown: children drain and exit, are not respawned, and the fork terminates - consistent with how `Forked` and `Threaded` containers handle a single interrupt.
				@stopping = true
				@group.interrupt
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
					Console.debug(self) do |buffer|
						buffer.puts "Waiting for ready:"
						@state.each do |child, state|
							buffer.puts "\t#{child.inspect}: #{state}"
						end
					end
					
					if self.status?(:ready)
						Console.debug(self) do |buffer|
							buffer.puts "All ready:"
							@state.each do |child, state|
								buffer.puts "\t#{child.inspect}: #{state}"
							end
						end
						
						return true
					end
					
					self.sleep
				end
			end
			
			# Stop the children instances.
			# @parameter timeout [Boolean | Numeric] Whether to stop gracefully, or a specific timeout.
			def stop(timeout = true)
				if @stopping
					Console.warn(self, "Container is already stopping!")
					return
				end
				
				Console.info(self, "Stopping container...", timeout: timeout)
				@stopping = true
				@group.stop(timeout)
				
				if @group.running?(except: current_task)
					Console.warn(self, "Group is still running after stopping it!")
				else
					Console.info(self, "Group has stopped.")
				end
			rescue => error
				Console.error(self, "Error while stopping container!", exception: error)
				raise
			end
			
			private def current_task
				Async::Task.current
			rescue RuntimeError
				nil
			end
			
			protected def health_check_failed(child, age_clock, health_check_timeout)
				begin
					@policy.health_check_failed(
						self, child,
						age: age_clock.total,
						timeout: health_check_timeout
					)
				rescue => error
					Console.error(self, "Policy error in health_check_failed!", exception: error)
					child.kill!
				end
			end
			
			protected def startup_failed(child, age_clock, startup_timeout)
				begin
					@policy.startup_failed(
						self, child,
						age: age_clock.total,
						timeout: startup_timeout
					)
				rescue => error
					Console.error(self, "Policy error in startup_failed!", exception: error)
					child.kill!
				end
			end
			
			# Spawn a child instance into the container.
			# @parameter name [String] The name of the child instance.
			# @parameter restart [Boolean] Whether to restart the child instance if it fails.
			# @parameter key [Symbol] A key used for reloading child instances.
			# @parameter health_check_timeout [Numeric | Nil] The maximum time a child instance can run without updating its state, before it is terminated as unhealthy.
			# @parameter startup_timeout [Numeric | Nil] The maximum time a child instance can run without becoming ready, before it is terminated as unhealthy.
			def spawn(name: nil, restart: false, key: nil, health_check_timeout: nil, startup_timeout: nil, &block)
				name ||= UNNAMED
				
				if mark?(key)
					Console.debug(self, "Reusing existing child.", child: {key: key, name: name})
					return false
				end
				
				@statistics.spawn!
				started = ::Thread::Queue.new
				
				@group.supervise do
					first = true
					
					until @stopping
						Console.debug(self, "Starting child...", child: {key: key, name: name, restart: restart, health_check_timeout: health_check_timeout}, statistics: @statistics)
						
						child = self.start(name, &block)
						state = insert(key, child)
						@group.insert(child)
						
						if first
							started << true
							first = false
						end
						
						# Notify policy of spawn
						begin
							@policy.child_spawn(self, child, name: name, key: key)
						rescue => error
							Console.error(self, "Policy error in child_spawn!", exception: error)
						end
						
						Console.debug(self, "Started child.", child: child, spawn: {key: key, restart: restart, health_check_timeout: health_check_timeout}, statistics: @statistics)
						
						# If a health check or startup timeout is specified, we will monitor the child process and terminate it if it does not update its state within the specified time.
						if health_check_timeout || startup_timeout
							age_clock = state[:age] = Clock.start
						end
						
						status = nil
						
						begin
							status = wait_for(child, state, age_clock, health_check_timeout, startup_timeout)
						rescue => error
							Console.error(self, "Error during child process management!", exception: error, stopping: @stopping)
						ensure
							@group.delete(child)
							delete(key, child)
						end
						
						if status&.success?
							Console.debug(self, "Child exited successfully.", status: status, stopping: @stopping)
						else
							@statistics.failure!
							Console.error(self, "Child exited with error!", status: status, stopping: @stopping)
						end
						
						# Notify policy of exit (after statistics are updated):
						begin
							@policy.child_exit(self, child, status, name: name, key: key)
						rescue => error
							Console.error(self, "Policy error in child_exit!", exception: error)
						end
						
						if restart && !@stopping
							@statistics.restart!
						else
							break
						end
					end
				rescue => error
					started << error if first
					raise
				ensure
					started << false if first
				end
				
				case result = started.pop
				when Exception
					raise result
				end
				
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
				# warn "#{self.class}##{__method__} is deprecated, please use `spawn` or `run` instead.", uplevel: 1
				
				require "async"
				
				spawn(**options) do |instance|
					Async(instance, &block)
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
			
			def wait_for(child, state, age_clock, health_check_timeout, startup_timeout)
				parent = Async::Task.current
				result = Async::Queue.new
				health = ::Thread::Queue.new if age_clock
				
				reader = parent.async do
					read_notifications(child, state, age_clock, health)
				end
				
				monitor = if age_clock
					parent.async do
						monitor_health(child, state, age_clock, health, health_check_timeout, startup_timeout)
					end
				end
				
				waiter = parent.async do
					begin
						result << child.wait
					rescue Exception => error
						result << error
					end
				end
				
				status = result.pop
				raise status if status.is_a?(Exception)
				
				return status
			ensure
				reader&.stop
				monitor&.stop
				waiter&.stop
			end
			
			def read_notifications(child, state, age_clock, health)
				while true
					child.in.wait_readable
					
					if message = child.receive
						state.update(message)
						
						# Reset the age clock if the child has become ready:
						if state[:ready]
							age_clock&.reset!
						end
						
						health&.push(true)
						@group.health_check!
					else
						break
					end
				end
			rescue IO::TimeoutError
				retry
			rescue IOError, Errno::EBADF
				# The notification pipe was closed while the child waiter was exiting.
			end
			
			def monitor_health(child, state, age_clock, health, health_check_timeout, startup_timeout)
				while true
					if timeout = next_timeout(state, age_clock, health_check_timeout, startup_timeout)
						health.pop(timeout: timeout)
						
						break if check_timeout(child, state, age_clock, health_check_timeout, startup_timeout)
					else
						health.pop(timeout: @group.health_check_interval || 1.0)
					end
				end
			end
			
			def next_timeout(state, age_clock, health_check_timeout, startup_timeout)
				timeout = if state[:ready]
					health_check_timeout
				else
					startup_timeout
				end
				
				return unless timeout
				
				remaining = timeout - age_clock.total
				
				if remaining.positive?
					remaining
				else
					0
				end
			end
			
			def check_timeout(child, state, age_clock, health_check_timeout, startup_timeout)
				if state[:ready]
					if health_check_timeout && health_check_timeout < age_clock.total
						health_check_failed(child, age_clock, health_check_timeout)
						return true
					end
				else
					if startup_timeout && startup_timeout < age_clock.total
						startup_failed(child, age_clock, startup_timeout)
						return true
					end
				end
				
				return false
			end
			
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
			
		end
	end
end
