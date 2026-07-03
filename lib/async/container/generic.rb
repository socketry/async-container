# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require "etc"
require "async/clock"
require "async/deadline"
require "set"
require "thread"

require_relative "group"
require_relative "statistics"
require_relative "policy"

module Async
	module Container
		# An environment variable key to override {.processor_count}.
		ASYNC_CONTAINER_PROCESSOR_COUNT = "ASYNC_CONTAINER_PROCESSOR_COUNT"
		
		# The processor count which may be used for the default number of container threads/processes.
		def self.processor_count(env = ENV)
			count = env.fetch(ASYNC_CONTAINER_PROCESSOR_COUNT) do
				Etc.nprocessors rescue 1
			end.to_i
			
			if count < 1
				raise RuntimeError, "Invalid processor count #{count}!"
			end
			
			return count
		end
		
		# A generic container which supervises children of a specific type.
		class Generic
			UNNAMED = "Unnamed"
			
			def self.run(...)
				self.new.run(...)
			end
			
			def initialize(child_type, policy: Policy::DEFAULT, **options)
				@child_type = child_type
				@group = Group.new(**options)
				
				@policy = policy
				@statistics = @policy.make_statistics
				
				@keyed = {}
				@threads = Set.new
				@mutex = Mutex.new
				@stopping = false
			end
			
			# @attribute [Group] The group of running children.
			attr :group
			
			# @attribute [Policy] The policy for managing child lifecycle events.
			attr_accessor :policy
			
			# @attribute [Statistics] Statistics relating to child lifecycle.
			attr :statistics
			
			# @returns [Integer] The number of running children.
			def size
				@group.size
			end
			
			# @returns [Hash(Child, Hash)] The current state for each child.
			def state
				@group.children.each_with_object({}) do |child, state|
					state[child] = child.state
				end
			end
			
			# Look up a child by key.
			def [](key)
				@mutex.synchronize{@keyed[key]}
			end
			
			# Whether any failures have occurred within the container.
			def failed?
				@statistics.failed?
			end
			
			# Whether the container has running children.
			def running?
				@group.running?
			end
			
			# Whether the container is stopping.
			def stopping?
				@stopping
			end
			
			# Sleep until a group event occurs or the specified duration elapses.
			def sleep(duration = nil)
				deadline = Deadline.new(duration) if duration
				
				loop do
					event = if deadline
						return nil if deadline.expired?
						
						@group.wait(deadline.remaining)
					else
						@group.wait
					end
					
					case event
					when Group::Spawn
						next
					else
						return event
					end
				end
			end
			
			# Wait until all lifecycle owner threads complete.
			def wait
				loop do
					current = Thread.current
					threads = @mutex.synchronize{@threads.reject{|thread| thread.equal?(current)}}
					break if threads.empty?
					
					threads.each do |thread|
						thread.join
						@mutex.synchronize{@threads.delete(thread)}
					end
				end
			end
			
			# Interrupt all children and enter the stopping state.
			def interrupt
				@stopping = true
				@group.interrupt!
			end
			
			# Returns true if all running children have the specified status flag.
			def status?(flag)
				@group.children.all?{|child| child.state[flag]}
			end
			
			# Wait until all running children report readiness.
			def wait_until_ready
				loop do
					return true if running? && status?(:ready)
					return false if failed? && !lifecycle_running?
					return true if !running? && !lifecycle_running?
					
					@group.wait
				end
			end
			
			# Stop all children.
			def stop(timeout = true)
				return if @stopping && !running?
				
				@stopping = true
				@group.stop(timeout)
				self.wait
			end
			
			# Spawn a child into the container.
			def spawn(name: nil, restart: false, key: nil, health_check_timeout: nil, startup_timeout: nil, **options, &block)
				name ||= UNNAMED
				
				if reuse?(key)
					return false
				end
				
				child = start_child(name: name, **options, &block)
				register_child(child, name: name, key: key)
				
				thread = Thread.new do
					manage_child(child, name: name, key: key, restart: restart, health_check_timeout: health_check_timeout, startup_timeout: startup_timeout, options: options, block: block)
				ensure
					@mutex.synchronize{@threads.delete(Thread.current)}
				end
				
				@mutex.synchronize{@threads.add(thread)}
				
				return true
			end
			
			# Run multiple instances of the same block in the container.
			def run(count: Container.processor_count, **options, &block)
				count.times do
					spawn(**options, &block)
				end
				
				return self
			end
			
			# @deprecated Please use {spawn} or {run} instead.
			def async(**options, &block)
				require "async"
				
				spawn(**options) do |instance|
					Async(instance, &block)
				end
			end
			
			# Re-run the given block against the container.
			def reload
				yield
			end
			
			# Whether a child exists for the given key.
			def key?(key)
				key && @mutex.synchronize{@keyed.key?(key)}
			end
			
			# Whether a child can be reused for the given key.
			def reuse?(key)
				key && @mutex.synchronize{@keyed.key?(key)}
			end
			
			protected
			
			def lifecycle_running?
				@mutex.synchronize{@threads.any?(&:alive?)}
			end
			
			def start_child(name:, **options, &block)
				@child_type.call(name: name, **options, &block)
			end
			
			def register_child(child, name:, key:)
				@statistics.spawn!
				
				@mutex.synchronize do
					@keyed[key] = child if key
				end
				
				@group.add(child)
				
				begin
					@policy.child_spawn(self, child, name: name, key: key)
				rescue => error
					Console.error(self, "Policy error in child_spawn!", exception: error) if defined?(Console)
				end
			end
			
			def unregister_child(child, status, key:)
				@mutex.synchronize do
					@keyed.delete(key) if key
				end
				
				@group.remove(child, status)
			end
			
			def manage_child(child, name:, key:, restart:, health_check_timeout:, startup_timeout:, options:, block:)
				loop do
					status = monitor_child(child, health_check_timeout: health_check_timeout, startup_timeout: startup_timeout)
					
					record_exit(child, status, name: name, key: key)
					unregister_child(child, status, key: key)
					notify_child_exit(child, status, name: name, key: key)
					
					if restart && !@stopping
						@statistics.restart!
						
						child = start_child(name: name, **options, &block)
						register_child(child, name: name, key: key)
					else
						break
					end
				end
			rescue => error
				Console.error(self, "Error during child lifecycle management!", exception: error, stopping: @stopping) if defined?(Console)
			ensure
				if @group.children.include?(child)
					begin
						@group.remove(child)
					rescue ArgumentError
					end
				end
			end
			
			def monitor_child(child, health_check_timeout:, startup_timeout:)
				if health_check_timeout || startup_timeout
					monitor_child_with_timeouts(child, health_check_timeout: health_check_timeout, startup_timeout: startup_timeout)
				else
					child.wait do |message|
						@group.update(child, message)
					end
				end
			end
			
			def monitor_child_with_timeouts(child, health_check_timeout:, startup_timeout:)
				loop do
					timeout = child.ready? ? health_check_timeout : startup_timeout
					result = child.receive(timeout)
					
					case result
					when false
						if child.ready?
							health_check_failed(child, health_check_timeout)
						else
							startup_failed(child, startup_timeout)
						end
						
						child.kill!
						
						return child.wait do |message|
							@group.update(child, message)
						end
					when nil
						return child.reap
					else
						@group.update(child, result)
					end
				end
			end
			
			def record_exit(child, status, name:, key:)
				if status&.success?
					Console.debug(self, "Child exited successfully.", status: status, stopping: @stopping) if defined?(Console)
				elsif @stopping
					Console.debug(self, "Child exited while stopping.", status: status, stopping: @stopping) if defined?(Console)
				else
					@statistics.failure!
					Console.error(self, "Child exited with error!", status: status, stopping: @stopping) if defined?(Console)
				end
			end
			
			def notify_child_exit(child, status, name:, key:)
				@policy.child_exit(self, child, status, name: name, key: key)
			rescue => error
				Console.error(self, "Policy error in child_exit!", exception: error) if defined?(Console)
				
			end
			
			def health_check_failed(child, timeout)
				@policy.health_check_failed(self, child, age: Clock.now - child.last_updated_at, timeout: timeout)
			rescue => error
				Console.error(self, "Policy error in health_check_failed!", exception: error) if defined?(Console)
				child.kill!
			end
			
			def startup_failed(child, timeout)
				@policy.startup_failed(self, child, age: Clock.now - child.last_updated_at, timeout: timeout)
			rescue => error
				Console.error(self, "Policy error in startup_failed!", exception: error) if defined?(Console)
				child.kill!
			end
		end
	end
end
