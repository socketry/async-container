# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.

require_relative "channel"
require_relative "error"

require_relative "notify/pipe"

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
						self.ready!(status: "(exec)")
					else
						self.before_spawn(arguments, options)
					end
					
					::Process.exec(*arguments, **options)
				end
			end
			
			# Fork a child process appropriate for a container.
			# @returns [Process]
			def self.fork(**options)
				self.new(**options) do |process|
					::Process.fork do
						# We use `Thread.current.raise(...)` so that exceptions are filtered through `Thread.handle_interrupt` correctly.
						Signal.trap(:INT) {::Thread.current.raise(Interrupt)}
						Signal.trap(:TERM) {::Thread.current.raise(Terminate)}
						Signal.trap(:HUP) {::Thread.current.raise(Restart)}
						
						# This could be a configuration option:
						::Thread.handle_interrupt(SignalException => :immediate) do
							yield Instance.for(process)
						rescue Interrupt
							# Graceful exit.
						rescue Exception => error
							Console.error(self, error)
							
							exit!(1)
						end
					end
				end
			end
			
			def self.spawn(*arguments, name: nil, **options)
				self.new(name: name) do |process|
					Notify::Pipe.new(process.out).before_spawn(arguments, options)
					
					::Process.spawn(*arguments, **options)
				end
			end
			
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
			
			# @attribute [Integer] The process identifier.
			attr :pid
			
			# A human readable representation of the process.
			# @returns [String]
			def inspect
				"\#<#{self.class} name=#{@name.inspect} status=#{@status.inspect} pid=#{@pid.inspect}>"
			end
			
			alias to_s inspect
			
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
			
			# Send `SIGHUP` to the child process.
			def restart!
				unless @status
					::Process.kill(:HUP, @pid)
				end
			end
			
			# Wait for the child process to exit.
			# @asynchronous This method may block.
			#
			# @returns [::Process::Status] The process exit status.
			def wait
				if @pid && @status.nil?
					Console.debug(self, "Waiting for process to exit...", pid: @pid)
					
					_, @status = ::Process.wait2(@pid, ::Process::WNOHANG)

					while @status.nil?
						sleep(0.1)
						
						_, @status = ::Process.wait2(@pid, ::Process::WNOHANG)
						
						if @status.nil?
							Console.warn(self) {"Process #{@pid} is blocking, has it exited?"}
						end
					end
				end
				
				Console.debug(self, "Process exited.", pid: @pid, status: @status)
				
				return @status
			end
		end
	end
end
