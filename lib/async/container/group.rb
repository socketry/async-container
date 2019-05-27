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
			end
			
			def spawn(*arguments)
				if pid = ::Process.spawn(*arguments)
					wait_for(pid)
				end
			end
			
			def fork(&block)
				if pid = ::Process.fork(&block)
					wait_for(pid)
				end
			end
			
			def kill(signal = :INT)
				::Process.kill(-@pgid, signal)
			end
			
			def close
				kill(:TERM)
			end
			
			def any?
				@running.any?
			end
			
			# Wait for one process, should only be called when a child process has finished, otherwise would block.
			def wait(flags = 0)
				return unless @pgid
				
				# Wait for processes in this group:
				pid, status = Process.wait2(-@pgid, flags)
			
				return if flags & Process::WNOHANG and pid == nil
			
				fiber = @running.delete(pid)
				
				if @running.empty?
					@pgid = nil
				end
				
				# This should never happen unless something very odd has happened:
				raise RuntimeError.new("Process id=#{pid} is not part of group!") unless fiber
				
				fiber.resume(status)
			end
			
			def wait_for(pid)
				if @pgid
					# Set this process as part of the existing process group:
					Process.setpgid(pid, @pgid)
				else
					# Establishes the child process as a process group leader:
					Process.setpgid(pid, 0)
					
					# Save the process group id:
					@pgid = pid
				end
				
				@running[pid] = Fiber.current
				
				# Return process status:
				return Fiber.yield
			end
		end
	end
end
