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
		class ContainerError < Error
			def initialize(container)
				super("Could not create container!")
				@container = container
			end
			
			attr :container
		end
		
		# Manages the life-cycle of a container.
		class Controller
			SIGHUP = Signal.list["HUP"]
			SIGINT = Signal.list["INT"]
			SIGTERM = Signal.list["TERM"]
			SIGUSR1 = Signal.list["USR1"]
			SIGUSR2 = Signal.list["USR2"]
			
			def initialize(startup_duration: nil)
				@container = nil
				
				# If there is no `NOTIFY_SOCKET` this will be nil:
				@notify = Notify::Client.open
				
				@signals = {}
				
				trap(SIGHUP, &self.method(:restart))
				
				@startup_duration = startup_duration
			end
			
			def trap(signal, &block)
				@signals[signal] = block
			end
			
			attr :container
			
			def create_container
				Container.new
			end
			
			def running?
				!!@container
			end
			
			def wait
				@container&.wait
			end
			
			def setup(container)
				# Don't do this, otherwise calling super is risky for sub-classes:
				# raise NotImplementedError, "Container setup is must be implemented in derived class!"
			end
			
			def start
				self.restart unless @container
			end
			
			def stop(graceful = true)
				@container&.stop(graceful)
				@container = nil
			end
			
			def restart(duration = @startup_duration)
				if @container
					@notify&.restarting!
					
					Async.logger.debug(self) {"Restarting container..."}
				else
					Async.logger.debug(self) {"Starting container..."}
				end
				
				container = self.create_container
				
				begin
					self.setup(container)
				rescue
					@notify&.error!($!.to_s)
					
					raise ContainerError, container
				end
				
				# Wait for all child processes to enter the ready state.
				Async.logger.debug(self) {"Waiting for container to become ready..."}
				container.sleep(duration)
				
				if container.failed?
					@notify&.error!($!.to_s)
					
					container.stop
					
					raise ContainerError, container
				end
				
				# Make this swap as atomic as possible:
				old_container = @container
				@container = container
				
				old_container&.stop
				@notify&.ready!
			rescue
				# If we are leaving this function with an exception, try to kill the container:
				container&.stop(false)
			end
			
			def reload(duration = @startup_duration)
				@notify&.reloading!
				
				Async.logger.info(self) {"Reloading container: #{@container}..."}
				
				begin
					self.setup(@container)
				rescue
					raise ContainerError, container
				end
				
				# Wait for all child processes to enter the ready state.
				Async.logger.debug(self, "Waiting for startup...")
				@container.sleep(duration)
				Async.logger.debug(self, "Finished startup.")
				
				if @container.failed?
					@notify.error!("Container failed!")
					raise ContainerError, @container
				else
					@notify&.ready!
				end
			end
			
			def run
				# I thought this was the default... but it doesn't always raise an exception unless you do this explicitly.
				interrupt_action = Signal.trap(:INT) do
					raise Interrupt
				end
				
				terminate_action = Signal.trap(:TERM) do
					raise Terminate
				end
				
				Async.logger.warn("starting")
				
				self.start
				
				Async.logger.warn("started: #{@container}")
				
				while @container
					begin
						@container.wait
					rescue SignalException => exception
						if handler = @signals[exception.signo]
							begin
								handler.call
							rescue ContainerError => failure
								Async.logger.error(self) {failure}
							end
						else
							raise
						end
					end
				end
			rescue Interrupt
				Async.logger.warn("run: #{$!} #{@container}")
				self.stop(true)
			rescue Terminate
				Async.logger.warn("run: #{$!} #{@container}")
				self.stop(false)
			else
				Async.logger.warn("run: graceful #{$!} #{@container}")
				self.stop(true)
			ensure
				# Restore the interrupt handler:
				Signal.trap(:INT, interrupt_action)
				Signal.trap(:TERM, terminate_action)
			end
		end
	end
end
