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

module Async
	module Container
		class ContainerFailed < Error
			def initialize(container)
				super("Could not create container!")
				@container = container
			end
			
			attr :container
		end
		
		# Manages the life-cycle of a container.
		class Controller
			SIGHUP = Signal.list["HUP"]
			DEFAULT_TIMEOUT = 2
			
			def initialize(startup_duration: DEFAULT_TIMEOUT)
				@container = nil
				
				@startup_duration = startup_duration
			end
			
			attr :container
			
			def create_container
				Container.new
			end
			
			def setup(container)
			end
			
			def start
				self.restart
			end
			
			def stop(graceful = true)
				@container&.stop(graceful)
				@container = nil
			end
			
			def restart(duration = @startup_duration)
				hup_action = Signal.trap(:HUP, :IGNORE)
				container = self.create_container
				
				begin
					self.setup(container)
				rescue
					raise ContainerFailed, container
				end
				
				Async.logger.debug(self, "Waiting for startup...")
				container.sleep(duration)
				Async.logger.debug(self, "Finished startup.")
				
				if container.failed?
					container.stop
					
					raise ContainerFailed, container
				end
				
				@container&.stop
				@container = container
			ensure
				Signal.trap(:HUP, hup_action)
			end
			
			def run
				Async.logger.debug(self) {"Starting container..."}
				
				self.start
				
				while true
					begin
						@container.wait
					rescue SignalException => exception
						if exception.signo == SIGHUP
							Async.logger.info(self) {"Reloading container..."}
							
							begin
								self.restart
							rescue ContainerFailed => failure
								Async.logger.error(self) {failure}
							end
						else
							raise
						end
					end
				end
			ensure
				self.stop
			end
		end
	end
end
