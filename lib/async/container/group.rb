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

require_relative 'controller'
require_relative 'statistics'

module Async
	# Manages a reactor within one or more threads.
	module Container
		class Group
			def initialize
				@pgid = nil
				@running = {}
				
				@queue = nil
			end
			
			def spawn(*arguments)
				self.yield
				
				if pid = ::Process.spawn(*arguments)
					wait_for(pid)
				end
			end
			
			def fork(&block)
				self.yield
				
				if pid = ::Process.fork(&block)
					wait_for(pid)
				end
			end
			
			def any?
				@running.any?
			end
			
			def sleep(duration)
				self.resume
				self.suspend
				
				Kernel::sleep(duration)
				
				while self.wait_one(::Process::WNOHANG)
				end
			end
			
			def wait
				self.resume
				
				while self.any?
					self.wait_one
				end
			end
			
			def kill(signal = :INT)
				::Process.kill(signal, -@pgid) if @pgid
			end
			
			def stop(graceful = false)
				if graceful
					self.kill(:INT)
					interrupt_all
				end
			ensure
				self.close
			end
			
			def close
				begin
					self.kill(:TERM)
				rescue Errno::EPERM
					# Sometimes, `kill` code can give EPERM, if any signal couldn't be delivered to a child. This might occur if an exception is thrown in the user code (e.g. within the fiber), and there are other zombie processes which haven't been reaped yet. These should be dealt with below, so it shouldn't be an issue to ignore this condition.
				end
				
				# Clean up zombie processes - if user presses Ctrl-C or for some reason something else blows up, exception would propagate back to caller:
				interrupt_all
			end
			
			protected
			
			def yield
				if @queue
					@queue << Fiber.current
					Fiber.yield
				end
			end
			
			def suspend
				@queue ||= []
			end
			
			def resume
				if @queue
					@queue.each(&:resume)
					@queue = nil
				end
			end
			
			def interrupt_all
				while self.any?
					self.wait_one do |fiber, status|
						begin
							# This causes the waiting fiber to `raise Interrupt`:
							fiber.resume(nil)
						rescue Interrupt
							# Graceful exit.
						end
					end
				end
			end
			
			# Wait for one process, should only be called when a child process has finished, otherwise would block.
			def wait_one(flags = 0)
				return unless @pgid
				
				# Wait for processes in this group:
				pid, status = ::Process.wait2(-@pgid, flags)
				
				return if flags & ::Process::WNOHANG and pid == nil
				
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
				
				@running[pid] = Fiber.current
				
				# Return process status:
				if result = Fiber.yield
					return result
				else
					raise Interrupt
				end
			end
		end
	end
end
