# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.

require_relative "error"
require_relative "best"

require_relative "statistics"
require_relative "notify"

module Async
	module Container
		# Manages the life-cycle of one or more containers in order to support a persistent system.
		# e.g. a web server, job server or some other long running system.
		class Controller
			SIGHUP = Signal.list["HUP"]
			SIGINT = Signal.list["INT"]
			SIGTERM = Signal.list["TERM"]
			SIGUSR1 = Signal.list["USR1"]
			SIGUSR2 = Signal.list["USR2"]
			
			# Initialize the controller.
			# @parameter notify [Notify::Client] A client used for process readiness notifications.
			def initialize(notify: Notify.open!, container_class: Container, graceful_stop: true)
				@container = nil
				@container_class = container_class
				
				@notify = notify
				@signals = {}
				
				self.trap(SIGHUP) do
					self.restart
				end
				
				@graceful_stop = graceful_stop
			end
			
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
				@signals[signal] = block
			end
			
			# The current container being managed by the controller.
			attr :container
			
			# Create a container for the controller.
			# Can be overridden by a sub-class.
			# @returns [Generic] A specific container instance to use.
			def create_container
				@container_class.new
			end
			
			# Whether the controller has a running container.
			# @returns [Boolean]
			def running?
				!!@container
			end
			
			# Wait for the underlying container to start.
			def wait
				@container&.wait
			end
			
			# Spawn container instances into the given container.
			# Should be overridden by a sub-class.
			# @parameter container [Generic] The container, generally from {#create_container}.
			def setup(container)
				# Don't do this, otherwise calling super is risky for sub-classes:
				# raise NotImplementedError, "Container setup is must be implemented in derived class!"
			end
			
			# Start the container unless it's already running.
			def start
				unless @container
					Console.info(self, "Controller starting...")
					self.restart
				end
				
				Console.info(self, "Controller started...")
			end
			
			# Stop the container if it's running.
			# @parameter graceful [Boolean] Whether to give the children instances time to shut down or to kill them immediately.
			def stop(graceful = @graceful_stop)
				@container&.stop(graceful)
				@container = nil
			end
			
			# Restart the container. A new container is created, and if successful, any old container is terminated gracefully.
			# This is equivalent to a blue-green deployment.
			def restart
				if @container
					@notify&.restarting!
					
					Console.info(self, "Restarting container...")
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
				container = nil
				
				if old_container
					Console.info(self, "Stopping old container...")
					old_container&.stop(@graceful_stop)
				end
				
				@notify&.ready!(size: @container.size)
			ensure
				# If we are leaving this function with an exception, kill the container:
				if container
					Console.info(self, "Stopping failed container...", exception: $!)
					container.stop(false)
				end
			end
			
			# Reload the existing container. Children instances will be reloaded using `SIGHUP`.
			def reload
				@notify&.reloading!
				
				Console.info(self){"Reloading container: #{@container}..."}
				
				begin
					self.setup(@container)
				rescue
					raise SetupError, container
				end
				
				# Wait for all child processes to enter the ready state.
				Console.info(self, "Waiting for startup...")
				@container.wait_until_ready
				Console.info(self, "Finished startup.")
				
				if @container.failed?
					@notify.error!("Container failed to reload!")
					
					raise SetupError, @container
				else
					@notify&.ready!
				end
			end
			
			# Enter the controller run loop, trapping `SIGINT` and `SIGTERM`.
			def run
				@notify&.status!("Initializing controller...")
				
				with_signal_handlers do
					self.start
					
					while @container&.running?
						begin
							@container.wait
						rescue SignalException => exception
							if handler = @signals[exception.signo]
								begin
									handler.call
								rescue SetupError => error
									Console.error(self, error)
								end
							else
								raise
							end
						end
					end
				end
			rescue Interrupt
				self.stop
			rescue Terminate
				self.stop(false)
			ensure
				self.stop(false)
			end
			
			private def with_signal_handlers
				# I thought this was the default... but it doesn't always raise an exception unless you do this explicitly.
				
				interrupt_action = Signal.trap(:INT) do
					# We use `Thread.current.raise(...)` so that exceptions are filtered through `Thread.handle_interrupt` correctly.
					# $stderr.puts "Received INT signal, interrupting...", caller
					::Thread.current.raise(Interrupt)
				end
				
				# SIGTERM behaves the same as SIGINT by default.
				terminate_action = Signal.trap(:TERM) do
					# $stderr.puts "Received TERM signal, interrupting...", caller
					::Thread.current.raise(Interrupt)  # Same as SIGINT
				end
				
				hangup_action = Signal.trap(:HUP) do
					# $stderr.puts "Received HUP signal, restarting...", caller
					::Thread.current.raise(Restart)
				end
				
				::Thread.handle_interrupt(SignalException => :never) do
					yield
				end
			ensure
				# Restore the interrupt handler:
				Signal.trap(:INT, interrupt_action)
				Signal.trap(:TERM, terminate_action)
				Signal.trap(:HUP, hangup_action)
			end
		end
	end
end
