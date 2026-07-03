# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "../child"
require_relative "instance"

module Async
	module Container
		module Threaded
			class Child < Container::Child
				def self.call(channel: Channel.new, name: nil, **options, &block)
					thread = ::Thread.new do
						begin
							yield Instance.for(channel, name: name)
						rescue Exit => exit
							Status.new(exit.error)
						rescue Interrupt
							# Graceful shutdown.
							Status.new
						rescue Exception => error
							Status.new(error)
						else
							Status.new
						ensure
							# Closing the write end tells the parent that no more messages are coming:
							channel.close_write unless channel.out.closed?
						end
					end
					
					return self.new(thread, channel, name: name, **options)
				end
				
				def initialize(thread, channel, **options)
					@thread = thread
					@status = nil
					
					super(channel, **options)
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
					@status ||= Status.new(:killed)
					
					@thread.kill
				end
				
				# Raise {Restart} in the child thread.
				def restart!
					@thread.raise(Restart)
				end
				
				def reap(timeout = nil)
					if timeout
						return nil unless @thread.join(timeout)
					else
						@thread.join
					end
					
					unless @status
						@status ||= @thread.value
					end
					
					return @status
				end
				
				# A pseudo exit-status wrapper for thread execution.
				class Status
					# Initialize the status.
					# @parameter error [Object | Nil] The error that caused the child thread to fail.
					def initialize(error = nil)
						@error = error
					end
					
					# The error that caused the child thread to fail.
					# @attribute [Object | Nil]
					attr :error
					
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
			end
		end
	end
end
