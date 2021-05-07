# frozen_string_literal: true

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
		# Represents a running child process from the point of view of the parent container.
		class Process < Channel
			# Represents a running child process from the point of view of the child process.
			class Instance < Notify::Pipe
				# Wrap an instance around the {Process} instance from within the forked child.
				# @parameter process [Process] The process intance to wrap.
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
				
				# Set the process title to the specified value.
				# @parameter value [String] The name of the process.
				def name= value
					if @name = value
						::Process.setproctitle(@name)
					end
				end
				
				# The name of the process.
				# @returns [String]
				def name
					@name
				end
				
				# Replace the current child process with a different one. Forwards arguments and options to {::Process.exec}.
				# This method replaces the child process with the new executable, thus this method never returns.
				def exec(*arguments, ready: true, **options)
					if ready
						self.ready!(status: "(exec)") if ready
					else
						self.before_spawn(arguments, options)
					end
					
					# TODO prefer **options... but it doesn't support redirections on < 2.7
					::Process.exec(*arguments, options)
				end
			end
			
			# Fork a child process appropriate for a container.
			# @returns [Process]
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
							Console.logger.error(self) {error}
							
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
			
			# Initialize the process.
			# @parameter name [String] The name to use for the child process.
			def initialize(name: nil)
				super()
				
				@name = name
				@status = nil
				@pid = nil
				
				@pid = yield(self)
				
				# The parent process won't be writing to the channel:
				self.close_write
			end
			
			# Set the name of the process.
			# Invokes {::Process.setproctitle} if invoked in the child process.
			def name= value
				@name = value
				
				# If we are the child process:
				::Process.setproctitle(@name) if @pid.nil?
			end
			
			# The name of the process.
			# @attribute [String]
			attr :name
			
			# A human readable representation of the process.
			# @returns [String]
			def to_s
				"\#<#{self.class} #{@name}>"
			end
			
			# Invoke {#terminate!} and then {#wait} for the child process to exit.
			def close
				self.terminate!
				self.wait
			ensure
				super
			end
			
			# Send `SIGINT` to the child process.
			def interrupt!
				unless @status
					::Process.kill(:INT, @pid)
				end
			end
			
			# Send `SIGTERM` to the child process.
			def terminate!
				unless @status
					::Process.kill(:TERM, @pid)
				end
			end
			
			# Wait for the child process to exit.
			# @returns [::Process::Status] The process exit status.
			def wait
				if @pid && @status.nil?
					_, @status = ::Process.wait2(@pid, ::Process::WNOHANG)
					
					if @status.nil?
						sleep(0.01)
						_, @status = ::Process.wait2(@pid, ::Process::WNOHANG)
					end
					
					if @status.nil?
						Console.logger.warn(self) {"Process #{@pid} is blocking, has it exited?"}
						_, @status = ::Process.wait2(@pid)
					end
				end
				
				return @status
			end
		end
	end
end
