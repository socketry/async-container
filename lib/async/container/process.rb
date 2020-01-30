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

require_relative 'notify/pipe'

module Async
	module Container
		class Process < Channel
			class Instance < Notify::Pipe
				def self.for(process)
					instance = self.new(process.out)
					
					# The child process won't be reading from the channel:
					process.close_read
					
					instance.name = process.name
					
					return instance
				end
				
				def initialize(io)
					super
					
					@name = nil
				end
				
				def name= value
					if @name = value
						::Process.setproctitle(@name)
					end
				end
				
				def name
					@name
				end
				
				def exec(*arguments, ready: true, **options)
					if ready
						self.ready!(status: "(exec)") if ready
					else
						self.before_exec(arguments)
					end
					
					::Process.exec(*arguments, **options)
				end
			end
			
			def self.fork(**options)
				self.new(**options) do |process|
					::Process.fork do
						Signal.trap(:INT) {raise Interrupt}
						Signal.trap(:TERM) {raise Terminate}
						
						begin
							yield Instance.for(process)
						rescue Interrupt
							# Graceful exit.
						rescue Exception => error
							Async.logger.error(self) {error}
							
							exit!(1)
						end
					end
				end
			end
			
			# def self.spawn(*arguments, name: nil, **options)
			# 	self.new(name: name) do |process|
			# 		unless options.key?(:out)
			# 			options[:out] = process.out
			# 		end
			# 
			# 		::Process.spawn(*arguments, **options)
			# 	end
			# end
			
			def initialize(name: nil)
				super()
				
				@name = name
				@status = nil
				@pid = nil
				
				@pid = yield(self)
				
				# The parent process won't be writing to the channel:
				self.close_write
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
				unless @status
					::Process.kill(:INT, @pid)
				end
			end
			
			def terminate!
				unless @status
					::Process.kill(:TERM, @pid)
				end
			end
			
			def wait
				if @pid && @status.nil?
					_, @status = ::Process.wait2(@pid, ::Process::WNOHANG)
					
					if @status.nil?
						sleep(0.01)
						_, @status = ::Process.wait2(@pid, ::Process::WNOHANG)
					end
					
					if @status.nil?
						Async.logger.warn(self) {"Process #{@pid} is blocking, has it exited?"}
						_, @status = ::Process.wait2(@pid)
					end
				end
				
				return @status
			end
		end
	end
end
