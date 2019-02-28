# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'async/reactor'
require 'process/group'

module Async
	# Manages a reactor within one or more threads.
	module Container
		class Forked
			class Instance
				def name= value
					::Process.setproctitle(value)
				end
			end
			
			def self.run(*args, &block)
				self.new.run(*args, &block)
			end
			
			def initialize
				@group = Process::Group.new
			end
			
			def run(processes: Container.processor_count, **options, &block)
				processes.times do
					async(**options, &block)
				end
				
				return self
			end
			
			def spawn(name: nil, restart: false)
				Fiber.new do
					while true
						exit_status = @group.fork do
							::Process.setproctitle(name) if name
							
							yield
						end
						
						unless exit_status.success?
							Async.logger.error("Process failed: #{exit_status}")
						end
						
						break if !restart
					end
				end.resume
				
				return self
			end
			
			def async(**options, &block)
				spawn(**options) do
					begin
						Async::Reactor.run(Instance.new, &block)
					rescue Interrupt
						# Graceful exit.
					end
				end
			end
			
			def self.multiprocess?
				true
			end
			
			def wait
				@group.wait
			end
			
			def stop(signal = :INT)
				@group.kill(signal)
			end
		end
	end
end
