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
require 'thread'

require_relative 'controller'
require_relative 'statistics'

module Async
	module Container
		# Manages a reactor within one or more threads.
		class Threaded < Controller
			class Instance
				def initialize(thread)
					@thread = thread
				end
				
				def name= value
					@thread.name = value
				end
				
				def exec(*arguments)
					pid = ::Process.spawn(*arguments)
					
					::Process.waitpid(pid)
				end
			end
			
			def self.run(*args, &block)
				self.new.run(*args, &block)
			end
			
			def self.multiprocess?
				false
			end
			
			def initialize
				super
				
				@threads = []
				@running = true
				@statistics = Statistics.new
			end
			
			attr :statistics
			
			def spawn(name: nil, restart: false, &block)
				@statistics.spawn!
				
				thread = ::Thread.new do
					thread = ::Thread.current
					
					thread.name = name if name
					
					instance = Instance.new(thread)
					
					while @running
						begin
							yield instance
						rescue Exception => exception
							Async.logger.error(self) {exception}
							
							@statistics.failure!
						end
						
						if restart
							@statistics.restart!
						else
							break
						end
					end
				# rescue Interrupt
				# 	# Graceful exit.
				end
				
				@threads << thread
				
				return self
			end
			
			def wait
				@threads.each(&:join)
				@threads.clear
				
				return nil
			rescue Interrupt
				# Graceful exit.
			end
			
			# Gracefully shut down all reactors.
			def stop(graceful = true)
				@running = false
				super
				
				if graceful
					@threads.each{|thread| thread.raise(Interrupt)}
				else
					@threads.each(&:kill)
				end
				
				self.wait
			ensure
				@running = true
			end
		end
	end
end
