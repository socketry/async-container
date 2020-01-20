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

module Async
	module Container
		module Forked
			class Group
				def initialize
					@pgid = nil
					@running = {}
					
					# This queue allows us to wait for processes to complete, without spawning new processes as a result.
					@queue = nil
				end
				
				def spawn(*arguments, **options)
					self.yield
					
					pid = ::Process.spawn(*arguments, **options)
					
					return Process.new(self, pid)
				end
				
				def fork(&block)
					self.yield
					
					pid = ::Process.fork(&block)
					
					return Process.new(self, pid)
				end
				
				def any?
					@running.any?
				end
				
				# This method sleeps for the specified duration, then 
				def sleep(duration)
					self.resume
					self.suspend
					
					::Kernel::sleep(duration)
					
					# This waits for any process to exit.
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
					if @pgid
						begin
							::Process.kill(signal, -@pgid)
						rescue Errno::EPERM
							# Sometimes, `kill` code can give EPERM, if any signal couldn't be delivered to a child. This might occur if an exception is thrown in the user code (e.g. within the fiber), and there are other zombie processes which haven't been reaped yet. These should be dealt with below, so it shouldn't be an issue to ignore this condition.
						end
					end
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
					self.kill(:TERM)
					
					# Clean up zombie processes - if user presses Ctrl-C or for some reason something else blows up, exception would propagate back to caller:
					interrupt_all
				ensure
					@pgid = nil
				end
				
				protected
				
				def yield
					if @queue
						fiber = Fiber.current
						
						@queue << fiber
						Fiber.yield
					end
				end
				
				def suspend
					@queue ||= []
				end
				
				def resume
					if @queue
						queue = @queue
						@queue = nil
						
						queue.each(&:resume)
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
				
				public
				
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
end