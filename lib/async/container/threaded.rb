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
require_relative 'statistics'

module Async
	module Container
		# Manages a reactor within one or more threads.
		class Threaded
			class Instance
				def initialize(thread)
					@thread = thread
				end
				
				def name= value
					@thread.name = value
				end
			end
			
			def self.run(*args, &block)
				self.new.run(*args, &block)
			end
			
			def initialize
				@reactors = []
				@threads = []
				@statistics = Statistics.new
			end
			
			attr :statistics
			
			def run(count: Container.processor_count, **options, &block)
				count.times do
					async(**options, &block)
				end
				
				return self
			end
			
			def spawn(name: nil, restart: false, &block)
				@statistics.spawn!
				
				thread = ::Thread.new do
					thread = ::Thread.current
					
					thread.abort_on_exception = true
					thread.name = name if name
					
					begin
						yield
					rescue Exception => exception
						Async.logger.error(self) {exception}
						
						@statistics.failure!
						
						# In theory this shuold be okay, but not quite as robust as using processes:
						if restart
							@statistics.restart!
							retry
						end
					end
				end
				
				@threads << thread
				
				return self
			end
			
			def async(name: nil, restart: false, &block)
				reactor = Async::Reactor.new
				
				@reactors << reactor
				
				@statistics.spawn!
				
				@threads << ::Thread.new do
					thread = ::Thread.current
					
					thread.abort_on_exception = true
					thread.name = name if name
					
					begin
						reactor.run(Instance.new(thread), &block)
					rescue Interrupt
						# Graceful exit.
						
					end
				end
				
				return self
			end
			
			def self.multiprocess?
				false
			end
			
			def wait
				yield if block_given?
				
				@threads.each(&:join)
				@threads.clear
				
				return nil
			end
			
			# Gracefully shut down all reactors.
			def stop
				@reactors.each(&:stop)
				@reactors.clear
				
				wait
			end
		end
	end
end
