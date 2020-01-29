# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative 'channel'
require_relative 'error'

module Async
	module Container
		class Process < Channel
			def self.fork(**options)
				self.new(**options) do |process|
					::Process.fork do
						Signal.trap(:INT) {raise Interrupt}
						Signal.trap(:TERM) {raise Terminate}
						
						begin
							process.close_read
							
							::Process.setproctitle(process.name)
							
							yield process
						rescue Interrupt
							# Graceful exit.
						rescue Exception => error
							Async.logger.error(self) {error}
							
							exit!(1)
						end
					end
				end
			end
			
			def self.spawn(*arguments, name: nil, **options)
				self.new(name: name) do |process|
					unless options.key?(:out)
						options[:out] = process.out
					end
					
					::Process.spawn(*arguments, **options)
				end
			end
			
			def initialize(name: nil)
				super()
				
				@name = name
				@status = nil
				@pid = nil
				
				@pid = yield self
				
				@out.close
			end
			
			def name= value
				@name = value
				
				# If we are the child process:
				::Process.setproctitle(@name) if @pid.nil?
			end
			
			attr :name
			
			def to_s
				if @status
					"\#<#{self.class} #{@name} -> #{@status}>"
				elsif @pid
					"\#<#{self.class} #{@name} -> #{@pid}>"
				else
					"\#<#{self.class} #{@name}>"
				end
			end
			
			def close
				self.terminate!
				self.wait
			ensure
				super
			end
			
			def interrupt!
				raise ArgumentError, "Cannot invoke from child process!" unless @pid
				
				unless @status
					::Process.kill(:INT, @pid)
				end
			end
			
			def terminate!
				raise ArgumentError, "Cannot invoke from child process!" unless @pid
				
				unless @status
					::Process.kill(:TERM, @pid)
				end
			end
			
			def wait
				raise ArgumentError, "Cannot invoke from child process!" unless @pid
				
				unless @status
					pid, @status = ::Process.wait2(@pid)
				end
				
				return @status
			end
		end
	end
end
