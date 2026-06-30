# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.

require_relative "error"
require_relative "best"

require_relative "statistics"
require_relative "notify"
require_relative "policy"

require "async"
require "async/signals"
require "async/signals/graceful"

module Async
	module Container
		# The default graceful stop policy for controllers.
		GRACEFUL_STOP = ENV.fetch("ASYNC_CONTAINER_GRACEFUL_STOP", "true").then do |value|
			case value
			when "true"
				true # Default timeout for graceful termination.
			when "false"
				false # Immediately kill the processes.
			else
				value.to_f
			end
		end
		
		# Manages the life-cycle of one or more containers in order to support a persistent system.
		# e.g. a web server, job server or some other long running system.
		class Controller
			# Represents a trapped process signal as a queued controller event.
			class SignalEvent
				# Initialize the signal event.
				# @parameter signal [Symbol | String | Integer] The signal that was received.
				# @parameter handler [Proc] The handler to invoke when the event is processed.
				def initialize(signal, handler)
					@signal = signal
					@handler = handler
				end
				
				# @attribute [Symbol | String | Integer] The signal that was received.
				attr :signal
				
				# Process the signal event by invoking the registered handler.
				def call
					@handler.call
				end
			end
			
			SIGHUP = Signal.list["HUP"]
			SIGUSR1 = Signal.list["USR1"]
			SIGUSR2 = Signal.list["USR2"]
			
			# Initialize the controller.
			# @parameter notify [Notify::Client] A client used for process readiness notifications.
			def initialize(notify: Notify.open!, container_class: Container, graceful_stop: GRACEFUL_STOP)
				@notify = notify
				@container_class = container_class
				@graceful_stop = graceful_stop
				
				@container = nil
				@events = ::Thread::Queue.new
				@signals = Async::Signals::Handlers.new
				
				# Serializes lifecycle transitions such as start, restart and reload. `Container#stop` (which can also take time) is performed outside this guard, so that live container events are not blocked by the stop operation (e.g. restarting).
				@guard = ::Thread::Mutex.new
				
				self.trap(SIGHUP) do
					self.restart
				rescue SetupError => error
					Console.error(self, error)
				end
				
				self.trap(SIGUSR1) do
					self.reload
				rescue SetupError => error
					Console.error(self, error)
				end
			end
			
			# The notify client used by the controller.
			attr :notify
			
			# The container class used by the controller.
			attr :container_class
			
			# The graceful stop flag used by the controller.
			attr :graceful_stop
			
			# The current container being managed by the controller.
			attr :container
			
			# The state of the controller.
			# @returns [String]
			def state_string
				if running?
					"running"
				else
					"stopped"
				end
			end
			
			# A human readable representation of the controller.
			# @returns [String]
			def to_s
				"#{self.class} #{state_string}"
			end
			
			# Trap the specified signal.
			# @parameters signal [Symbol] The signal to trap, e.g. `:INT`.
			# @parameters block [Proc] The signal handler to invoke.
			def trap(signal, &block)
				if block
					event = SignalEvent.new(signal, block).freeze
					
					@signals.trap(signal) do
						@events << event
					end
				else
					@signals.ignore(signal)
				end
			end
			
			# Create a policy for managing child lifecycle events.
			# Can be overridden by a sub-class to provide a custom policy.
			# @returns [Policy] The policy to use for the container.
			def make_policy
				Policy::DEFAULT
			end
			
			# Create a container for the controller.
			# Can be overridden by a sub-class.
			# @returns [Generic] A specific container instance to use.
			def create_container
				@container_class.new(policy: self.make_policy)
			end
			
			# Whether the controller has a running container.
			# @returns [Boolean]
			def running?
				@guard.synchronize{!!@container}
			end
			
			# Wait for the underlying container to start.
			def wait
				@guard.synchronize{@container}&.wait
			end
			
			# Spawn container instances into the given container.
			# Should be overridden by a sub-class.
			# @parameter container [Generic] The container, generally from {#create_container}.
			def setup(container)
				# Don't do this, otherwise calling super is risky for sub-classes:
				# raise NotImplementedError, "Container setup is must be implemented in derived class!"
			end
			
			# Start the container unless it's already running.
			# @returns [Generic] The container.
			def restart
				self.start(restart: true)
			end
			
			# Stop the container if it's running.
			# @parameter graceful [Boolean | Numeric] Whether to give the children instances time to shut down or to kill them immediately.
			def stop(graceful = @graceful_stop)
				container = nil
				
				@guard.synchronize do
					if container = @container
						@container = nil
					end
				end
				
				container&.stop(graceful)
			end
			
			# Restart the container. A new container is created, and if successful, any old container is terminated gracefully.
			# This is equivalent to a blue-green deployment.
			def start(restart: false)
				old_container = nil
				new_container = nil
				
				@guard.synchronize do
					if @container
						if restart
							@notify&.restarting!
							
							Console.info(self, "Restarting container...")
						else
							return @container
						end
					else
						Console.info(self, "Starting container...")
					end
						
					container = self.create_container
					
					begin
						self.setup(container)
					rescue => error
						@notify&.error!(error.to_s)
						
						raise SetupError, container
					end
					
					# Wait for all child processes to enter the ready state.
					Console.info(self, "Waiting for startup...")
					
					container.wait_until_ready
					
					Console.info(self, "Finished startup.")
					
					if container.failed?
						@notify&.error!("Container failed to start!")
						
						raise SetupError, container
					end
					
					# The following swap should be atomic:
					old_container = @container
					@container = container
					new_container = container
					container = nil
					
					@notify&.ready!(size: @container.size, status: "Running with #{@container.size} children.")
				rescue => error
					raise
				ensure
					# If we are leaving this function with an exception, kill the container:
					if container
						Console.warn(self, "Stopping failed container...", exception: error)
						container.stop(false)
					end
				end
				
				if old_container
					Console.info(self, "Stopping old container...")
					old_container.stop(@graceful_stop)
				end
				
				return new_container
			end
			
			# Reload the existing container. Children instances will be reloaded using `SIGHUP`.
			def reload
				@guard.synchronize do
					@notify&.reloading!
					
					Console.info(self){"Reloading container: #{@container}..."}
					
					begin
						self.setup(@container)
					rescue
						raise SetupError, @container
					end
					
					# Wait for all child processes to enter the ready state.
					Console.info(self, "Waiting for startup...")
					@container.wait_until_ready
					Console.info(self, "Finished startup.")
					
					if @container.failed?
						@notify.error!("Container failed to reload!")
						
						raise SetupError, @container
					else
						@notify&.ready!(size: @container.size, status: "Running with #{@container.size} children.")
					end
				end
			end
			
			private def wait_for_container
				while true
					container = @guard.synchronize{@container}
					
					if container.nil?
						@events.close
						return
					end
					
					container.wait
					
					@guard.synchronize do
						# If this is still the active container, it completed naturally. Clear it and close the event queue so the controller run loop can finish. If it was replaced by a restart, keep waiting for the new active container.
						if @container.equal?(container)
							@container = nil
							@events.close
							return
						end
					end
				end
			end
			
			# Enter the controller run loop.
			# @parameter signals [#install] The signal backend to use while running the controller.
			def run(signals: Async::Signals.default)
				@notify&.status!("Initializing controller...")
				
				signals.install(@signals) do
					Sync do |task|
						self.start
						
						waiter = task.async{wait_for_container}
						
						while event = @events.pop
							event.call
						end
					rescue Async::Cancel
						# Graceful shutdown:
						self.stop
					ensure
						# Forced shutdown:
						self.stop(false)
					end
				end
			rescue Interrupt
				self.stop(false)
			end
		end
	end
end
