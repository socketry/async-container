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

require 'async/io/notification'

module Async
	# Manages a reactor within one or more threads.
	module Container
		class Forked
			class Instance
				def initialize
				end
				
				def name= value
					Process.setproctitle(value)
				end
			end
			
			def initialize(concurrency: 1, name: nil, &block)
				@pids = concurrency.times.collect do
					fork do
						Process.setproctitle(name) if name
						
						begin
							Async::Reactor.run(Instance.new, &block)
						rescue Interrupt
							# Exit cleanly.
						end
					end
				end
				
				@finished = false
			end
			
			def wait
				return if @finished
				
				@pids.each do |pid|
					::Process.wait(pid)
				end

				@finished = true
			end
			
			def stop(signal = :TERM)
				@pids.each do |pid|
					::Process.kill(signal, pid) rescue nil
				end
				
				wait
			end
		end
	end
end
