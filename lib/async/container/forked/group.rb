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

require_relative 'process'
require_relative '../group'

module Async
	module Container
		module Forked
			class Group < Async::Container::Group
				def initialize
					@pgid = nil
					
					super
				end
				
				def spawn(*arguments, **options)
					self.yield
					
					arguments = self.prepare_for_spawn(arguments)
					
					pid = ::Process.spawn(*arguments, **options)
					
					return Process.new(self, pid)
				end
				
				def fork(&block)
					self.yield
					
					pid = ::Process.fork do
						self.after_fork
						
						yield
					end
					
					return Process.new(self, pid)
				end
				
				def kill(signal = :INT)
					if @pgid
						begin
							Async.logger.warn("Process.kill signal: #{signal} process group: #{@pgid}")
							::Process.kill(signal, -@pgid)
						rescue Errno::EPERM
							# Sometimes, `kill` code can give EPERM, if any signal couldn't be delivered to a child. This might occur if an exception is thrown in the user code (e.g. within the fiber), and there are other zombie processes which haven't been reaped yet. These should be dealt with below, so it shouldn't be an issue to ignore this condition.
						end
					end
				end
				
				def interrupt
					kill(:INT)
				end
				
				def terminate
					kill(:TERM)
				end
				
				def close
					super
				ensure
					@pgid = nil
				end
				
				def wait_for(pid)
					if @pgid
						# Set this process as part of the existing process group:
						::Process.setpgid(pid, @pgid)
					else
						# Establishes the child process as a process group leader:
						::Process.setpgid(pid, 0)
						
						# Save the process group id:
						@pgid = pid
					end
					
					super
				end
				
				protected
				
				# Wait for one process, should only be called when a child process has finished, otherwise would block.
				def wait_one(blocking = true)
					return unless @pgid
					
					flags = 0
					
					unless blocking
						flags |= ::Process::WNOHANG
					end
					
					# Wait for processes in this group:
					pid, status = ::Process.wait2(-@pgid, flags)
					
					return if !blocking && pid == nil
					
					fiber = @running.delete(pid)
					
					if @running.empty?
						@pgid = nil
					end
					
					if block_given?
						yield fiber, status
					else
						fiber.resume(status)
					end
				end
			end
		end
	end
end