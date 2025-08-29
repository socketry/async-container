# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2025, by Samuel Williams.

require_relative "generic"
require_relative "channel"
require_relative "notify/pipe"

module Async
	module Container
		# A multi-thread container which uses {Thread.fork}.
		class Threaded < Generic
			# Indicates that this is not a multi-process container.
			def self.multiprocess?
				false
			end
			
			# Represents a running child thread from the point of view of the parent container.
			class Child < Channel
				# Used to propagate the exit status of a child process invoked by {Instance#exec}.
				class Exit < Exception
					# Initialize the exit status.
					# @parameter status [::Process::Status] The process exit status.
					def initialize(status)
						@status = status
					end
					
					# The process exit status.
					# @attribute [::Process::Status]
					attr :status
					
					# The process exit status if it was an error.
					# @returns [::Process::Status | Nil]
					def error
						unless status.success?
							status
						end
					end
				end
				
				# Represents a running child thread from the point of view of the child thread.
				class Instance < Notify::Pipe
					# Wrap an instance around the {Thread} instance from within the threaded child.
					# @parameter thread [Thread] The thread intance to wrap.
					def self.for(thread)
						instance = self.new(thread.out)
						
						return instance
					end
					
					# Initialize the child thread instance.
					#
					# @parameter io [IO] The IO object to use for communication with the parent.
					def initialize(io)
						@thread = ::Thread.current
						
						super
					end
					
					# Generate a hash representation of the thread.
					#
					# @returns [Hash] The thread as a hash, including `process_id`, `thread_id`, and `name`.
					def as_json(...)
						{
							process_id: ::Process.pid,
							thread_id: @thread.object_id,
							name: @thread.name,
						}
					end
					
					# Generate a JSON representation of the thread.
					#
					# @returns [String] The thread as JSON.
					def to_json(...)
						as_json.to_json(...)
					end
					
					# Set the name of the thread.
					# @parameter value [String] The name to set.
					def name= value
						@thread.name = value
					end
					
					# Get the name of the thread.
					# @returns [String]
					def name
						@thread.name
					end
					
					# Execute a child process using {::Process.spawn}. In order to simulate {::Process.exec}, an {Exit} instance is raised to propagage exit status.
					# This creates the illusion that this method does not return (normally).
					def exec(*arguments, ready: true, **options)
						if ready
							self.ready!(status: "(spawn)")
						else
							self.before_spawn(arguments, options)
						end
						
						begin
							pid = ::Process.spawn(*arguments, **options)
						ensure
							_, status = ::Process.wait2(pid)
							
							raise Exit, status
						end
					end
				end
				
				# Start a new child thread and execute the provided block in it.
				#
				# @parameter options [Hash] Additional options to to the new child instance.
				def self.fork(**options)
					self.new(**options) do |thread|
						::Thread.new do
							# This could be a configuration option (see forked implementation too):
							::Thread.handle_interrupt(SignalException => :immediate) do
								yield Instance.for(thread)
							end
						end
					end
				end
				
				# Initialize the thread.
				#
				# @parameter name [String] The name to use for the child thread.
				def initialize(name: nil)
					super()
					
					@status = nil
					
					@thread = yield(self)
					@thread.report_on_exception = false
					@thread.name = name
					
					@waiter = ::Thread.new do
						begin
							@thread.join
						rescue Exit => exit
							finished(exit.error)
						rescue Interrupt
							# Graceful shutdown.
							finished
						rescue Exception => error
							finished(error)
						else
							finished
						end
					end
				end
				
				# Convert the child process to a hash, suitable for serialization.
				#
				# @returns [Hash] The request as a hash.
				def as_json(...)
					{
						name: @thread.name,
						status: @status&.as_json,
					}
				end
				
				# Convert the request to JSON.
				#
				# @returns [String] The request as JSON.
				def to_json(...)
					as_json.to_json(...)
				end
				
				# Set the name of the thread.
				# @parameter value [String] The name to set.
				def name= value
					@thread.name = value
				end
				
				# Get the name of the thread.
				# @returns [String]
				def name
					@thread.name
				end
				
				# A human readable representation of the thread.
				# @returns [String]
				def to_s
					"\#<#{self.class} #{@thread.name}>"
				end
				
				# Invoke {#terminate!} and then {#wait} for the child thread to exit.
				def close
					self.terminate!
					self.wait
				ensure
					super
				end
				
				# Raise {Interrupt} in the child thread.
				def interrupt!
					@thread.raise(Interrupt)
				end
				
				# Raise {Terminate} in the child thread.
				def terminate!
					@thread.raise(Terminate)
				end
				
				# Invoke {Thread#kill} on the child thread.
				def kill!
					# Killing a thread does not raise an exception in the thread, so we need to handle the status here:
					@status = Status.new(:killed)
					
					@thread.kill
				end
				
				# Raise {Restart} in the child thread.
				def restart!
					@thread.raise(Restart)
				end
				
				# Wait for the thread to exit and return he exit status.
				# @asynchronous This method may block.
				#
				# @parameter timeout [Numeric | Nil] Maximum time to wait before forceful termination.
				# @returns [Status]
				def wait(timeout = 0.1)
					if @waiter
						Console.debug(self, "Waiting for thread to exit...", timeout: timeout)
						
						unless @waiter.join(timeout)
							Console.warn(self) {"Thread #{@thread} is blocking, sending kill signal..."}
							self.kill!
							@waiter.join
						end
						
						@waiter = nil
					end
					
					return @status
				end
				
				# A pseudo exit-status wrapper.
				class Status
					# Initialise the status.
					# @parameter error [::Process::Status] The exit status of the child thread.
					def initialize(error = nil)
						@error = error
					end
					
					# Whether the status represents a successful outcome.
					# @returns [Boolean]
					def success?
						@error.nil?
					end
					
					# Convert the status to a hash, suitable for serialization.
					#
					# @returns [Boolean | String] If the status is an error, the error message is returned, otherwise `true`.
					def as_json(...)
						if @error
							@error.inspect
						else
							true
						end
					end
					
					# A human readable representation of the status.
					def to_s
						"\#<#{self.class} #{success? ? "success" : "failure"}>"
					end
				end
				
				protected
				
				# Invoked by the @waiter thread to indicate the outcome of the child thread.
				def finished(error = nil)
					if error
						Console.error(self) {error}
					end
					
					@status ||= Status.new(error)
					self.close_write
				end
			end
			
			# Start a named child thread and execute the provided block in it.
			# @parameter name [String] The name (title) of the child process.
			# @parameter block [Proc] The block to execute in the child process.
			def start(name, &block)
				Child.fork(name: name, &block)
			end
		end
	end
end
