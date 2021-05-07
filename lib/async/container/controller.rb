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

require_relative 'error'
require_relative 'best'

require_relative 'statistics'
require_relative 'notify'

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
			def initialize(notify: Notify.open!)
				@container = nil
				
				if @notify = notify
					@notify.status!("Initializing...")
				end
				
				@signals = {}
				
				trap(SIGHUP) do
					self.restart
				end
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
				Container.new
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
				self.restart unless @container
			end
			
			# Stop the container if it's running.
			# @parameter graceful [Boolean] Whether to give the children instances time to shut down or to kill them immediately.
			def stop(graceful = true)
				@container&.stop(graceful)
				@container = nil
			end
			
			# Restart the container. A new container is created, and if successful, any old container is terminated gracefully.
			def restart
				if @container
					@notify&.restarting!
					
					Console.logger.debug(self) {"Restarting container..."}
				else
					Console.logger.debug(self) {"Starting container..."}
				end
				
				container = self.create_container
				
				begin
					self.setup(container)
				rescue
					@notify&.error!($!.to_s)
					
					raise SetupError, container
				end
				
				# Wait for all child processes to enter the ready state.
				Console.logger.debug(self, "Waiting for startup...")
				container.wait_until_ready
				Console.logger.debug(self, "Finished startup.")
				
				if container.failed?
					@notify&.error!($!.to_s)
					
					container.stop
					
					raise SetupError, container
				end
				
				# Make this swap as atomic as possible:
				old_container = @container
				@container = container
				
				Console.logger.debug(self, "Stopping old container...")
				old_container&.stop
				@notify&.ready!
			rescue
				# If we are leaving this function with an exception, try to kill the container:
				container&.stop(false)
				
				raise
			end
			
			# Reload the existing container. Children instances will be reloaded using `SIGHUP`.
			def reload
				@notify&.reloading!
				
				Console.logger.info(self) {"Reloading container: #{@container}..."}
				
				begin
					self.setup(@container)
				rescue
					raise SetupError, container
				end
				
				# Wait for all child processes to enter the ready state.
				Console.logger.debug(self, "Waiting for startup...")
				@container.wait_until_ready
				Console.logger.debug(self, "Finished startup.")
				
				if @container.failed?
					@notify.error!("Container failed!")
					
					raise SetupError, @container
				else
					@notify&.ready!
				end
			end
			
			# Enter the controller run loop, trapping `SIGINT` and `SIGTERM`.
			def run
				# I thought this was the default... but it doesn't always raise an exception unless you do this explicitly.
				interrupt_action = Signal.trap(:INT) do
					raise Interrupt
				end
				
				terminate_action = Signal.trap(:TERM) do
					raise Terminate
				end
				
				hangup_action = Signal.trap(:HUP) do
					raise Hangup
				end
				
				self.start
				
				while @container&.running?
					begin
						@container.wait
					rescue SignalException => exception
						if handler = @signals[exception.signo]
							begin
								handler.call
							rescue SetupError => error
								Console.logger.error(self) {error}
							end
						else
							raise
						end
					end
				end
			rescue Interrupt
				self.stop(true)
			rescue Terminate
				self.stop(false)
			ensure
				self.stop(true)
				
				# Restore the interrupt handler:
				Signal.trap(:INT, interrupt_action)
				Signal.trap(:TERM, terminate_action)
				Signal.trap(:HUP, hangup_action)
			end
		end
	end
end
