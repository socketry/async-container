# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2026, by Samuel Williams.

require_relative "error"

require_relative "generic"
require_relative "channel"
require_relative "notify/pipe"

module Async
	module Container
		# A multi-process container which uses {Process.fork}.
		class Forked < Generic
			# Indicates that this is a multi-process container.
			def self.multiprocess?
				true
			end
			
			# Represents a running child process from the point of view of the parent container.
			class Child < Channel
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
					
					# Initialize the child process instance.
					#
					# @parameter io [IO] The IO object to use for communication.
					def initialize(io)
						super
						
						@name = nil
					end
					
					# Generate a hash representation of the process.
					#
					# @returns [Hash] The process as a hash, including `process_id` and `name`.
					def as_json(...)
						{
							process_id: ::Process.pid,
							name: @name,
						}
					end
					
					# Generate a JSON representation of the process.
					#
					# @returns [String] The process as JSON.
					def to_json(...)
						as_json.to_json(...)
					end
					
					# Set the process title to the specified value.
					#
					# @parameter value [String] The name of the process.
					def name= value
						@name = value
						
						# This sets the process title to an empty string if the name is nil:
						::Process.setproctitle(@name.to_s)
					end
					
					# @returns [String] The name of the process.
					def name
						@name
					end
					
					# Replace the current child process with a different one. Forwards arguments and options to {::Process.exec}.
					# This method replaces the child process with the new executable, thus this method never returns.
					#
					# @parameter arguments [Array] The arguments to pass to the new process.
					# @parameter ready [Boolean] If true, informs the parent process that the child is ready. Otherwise, the child process will need to use a notification protocol to inform the parent process that it is ready.
					# @parameter options [Hash] Additional options to pass to {::Process.exec}.
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
				#
				# @returns [Process]
				def self.fork(**options)
					# $stderr.puts fork: caller
					self.new(**options) do |process|
						::Process.fork do
							# We use `Thread.current.raise(...)` so that exceptions are filtered through `Thread.handle_interrupt` correctly.
							Signal.trap(:INT){::Thread.current.raise(Interrupt)}
							Signal.trap(:TERM){::Thread.current.raise(Terminate)}
							Signal.trap(:HUP){::Thread.current.raise(Restart)}
							
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
				
				# Spawn a child process using {::Process.spawn}.
				#
				# The child process will need to inform the parent process that it is ready using a notification protocol.
				#
				# @parameter arguments [Array] The arguments to pass to the new process.
				# @parameter name [String] The name of the process.
				# @parameter options [Hash] Additional options to pass to {::Process.spawn}.
				def self.spawn(*arguments, name: nil, **options)
					self.new(name: name) do |process|
						Notify::Pipe.new(process.out).before_spawn(arguments, options)
						
						::Process.spawn(*arguments, **options)
					end
				end
				
				# Initialize the process.
				# @parameter name [String] The name to use for the child process.
				def initialize(name: nil, **options)
					super(**options)
					
					@name = name
					@status = nil
					@pid = nil
					
					@pid = yield(self)
					
					# The parent process won't be writing to the channel:
					self.close_write
				end
				
				# Convert the child process to a hash, suitable for serialization.
				#
				# @returns [Hash] The request as a hash.
				def as_json(...)
					{
						name: @name,
						pid: @pid,
						status: @status&.to_i,
					}
				end
				
				# Convert the request to JSON.
				#
				# @returns [String] The request as JSON.
				def to_json(...)
					as_json.to_json(...)
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
				
				# @returns [String] A string representation of the process.
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
				
				# Send `SIGKILL` to the child process.
				def kill!
					unless @status
						::Process.kill(:KILL, @pid)
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
				# @parameter timeout [Numeric | Nil] Maximum time to wait before forceful termination.
				# @returns [::Process::Status] The process exit status.
				def wait(timeout = 0.1)
					if @pid && @status.nil?
						Console.debug(self, "Waiting for process to exit...", child: {process_id: @pid}, timeout: timeout)
						
						_, @status = ::Process.wait2(@pid, ::Process::WNOHANG)
						
						if @status.nil?
							sleep(timeout) if timeout
							
							_, @status = ::Process.wait2(@pid, ::Process::WNOHANG)
							
							if @status.nil?
								Console.warn(self, "Process is blocking, sending kill signal...", child: {process_id: @pid}, caller: caller_locations, timeout: timeout)
								self.kill!
								
								# Wait for the process to exit:
								_, @status = ::Process.wait2(@pid)
							end
						end
					end
					
					Console.debug(self, "Process exited.", child: {process_id: @pid, status: @status})
					
					return @status
				end
			end
			
			# Start a named child process and execute the provided block in it.
			# @parameter name [String] The name (title) of the child process.
			# @parameter block [Proc] The block to execute in the child process.
			def start(name, &block)
				Child.fork(name: name, &block)
			end
		end
	end
end
