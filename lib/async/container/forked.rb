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
require_relative 'statistics'

module Async
	# Manages a reactor within one or more threads.
	module Container
		class Forked
			UNNAMED = "Unnamed"
			
			class Instance
				def name= value
					::Process.setproctitle(value)
				end
			end
			
			def self.run(*args, &block)
				self.new.run(*args, &block)
			end
			
			def initialize
				@group = ::Process::Group.new
				@statistics = Statistics.new
				
				@running = true
			end
			
			attr :statistics
			
			def run(count: Container.processor_count, **options, &block)
				count.times do
					async(**options, &block)
				end
				
				return self
			end
			
			def spawn(name: nil, restart: false)
				Fiber.new do
					while @running
						@statistics.spawn!
						exit_status = @group.fork do
							::Process.setproctitle(name) if name
							
							yield Instance.new
						end
						
						if exit_status.success?
							Async.logger.info(self) {"#{name || UNNAMED} #{exit_status}"}
						else
							@statistics.failure!
							Async.logger.error(self) {exit_status}
						end
						
						if restart
							@statistics.restart!
						else
							break
						end
					end
				end.resume
				
				return self
			end
			
			def async(**options, &block)
				spawn(**options) do |instance|
					begin
						Async::Reactor.run(instance, &block)
					rescue Interrupt
						# Graceful exit.
					end
				end
			end
			
			def self.multiprocess?
				true
			end
			
			def wait(&block)
				@group.wait(&block)
			rescue Interrupt
				# Graceful exit.
			end
			
			# Gracefully shut down all children processes.
			def stop(graceful = true, &block)
				@running = false
				
				@group.kill(graceful ? :INT : :TERM)
				
				self.wait(&block)
			ensure
				@running = true
			end
		end
	end
end
