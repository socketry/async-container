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
		# Represents a running child thread from the point of view of the parent container.
		class Thread < Channel
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
				
				def initialize(io)
					@name = nil
					@thread = ::Thread.current
					
					super
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
						self.ready!(status: "(spawn)") if ready
					else
						self.before_spawn(arguments, options)
					end
					
					begin
						# TODO prefer **options... but it doesn't support redirections on < 2.7
						pid = ::Process.spawn(*arguments, options)
					ensure
						_, status = ::Process.wait2(pid)
						
						raise Exit, status
					end
				end
			end
			
			def self.fork(**options)
				self.new(**options) do |thread|
					::Thread.new do
						yield Instance.for(thread)
					end
				end
			end
			
			# Initialize the thread.
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
			
			# Wait for the thread to exit and return he exit status.
			# @returns [Status]
			def wait
				if @waiter
					@waiter.join
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
				
				# A human readable representation of the status.
				def to_s
					"\#<#{self.class} #{success? ? "success" : "failure"}>"
				end
			end
			
			protected
			
			# Invoked by the @waiter thread to indicate the outcome of the child thread.
			def finished(error = nil)
				if error
					Console.logger.error(self) {error}
				end
				
				@status = Status.new(error)
				self.close_write
			end
		end
	end
end
