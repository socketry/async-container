# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "../child"
require_relative "instance"

module Async
	module Container
		module Forked
			# Represents a child process managed by a forked container.
			class Child < Container::Child
				# Start a child process using `fork`.
				# @parameter channel [Channel] The notification channel for the child.
				# @parameter name [String | Nil] The optional child name.
				# @parameter options [Hash] Additional child options.
				# @yields {|instance| ...} The child process body.
				# 	@parameter instance [Instance] The child-side instance interface.
				# @returns [Child] The forked child process.
				def self.call(channel: Channel.new, name: nil, **options, &block)
					process_id = ::Thread.new do
						::Process.fork do
							begin
								Signal.trap(:INT){::Thread.current.raise(Interrupt)}
								Signal.trap(:TERM){::Thread.current.raise(Interrupt)}
								Signal.trap(:HUP){::Thread.current.raise(Restart)}
								
								::Thread.handle_interrupt(SignalException => :immediate) do
									yield Instance.for(channel, name: name)
								end
							rescue Interrupt
								# Graceful shutdown.
							rescue Restart
								# Graceful restart.
							rescue Exception
								exit!(1)
							ensure
								channel.close_write unless channel.out.closed?
							end
						end
					end.value
					
					# The parent process won't be writing to the channel:
					channel.close_write
					
					return self.new(process_id, channel, name: name, **options)
				end
				
				# Initialize the child process wrapper.
				# @parameter process_id [Integer] The process identifier.
				# @parameter channel [Channel] The notification channel for the child.
				# @parameter options [Hash] Additional child options.
				def initialize(process_id, channel, **options)
					@process_id = process_id
					@status = nil
					
					super(channel, **options)
				end
				
				# The process identifier.
				# @attribute [Integer]
				attr :process_id
				
				# Send `SIGINT` to the child process.
				def interrupt!
					unless @status
						::Process.kill(:INT, @process_id)
					end
				end
				
				# Send `SIGTERM` to the child process.
				def terminate!
					unless @status
						::Process.kill(:TERM, @process_id)
					end
				end
				
				# Send `SIGKILL` to the child process.
				def kill!
					unless @status
						::Process.kill(:KILL, @process_id)
					end
				end
				
				# Send `SIGHUP` to the child process.
				def restart!
					unless @status
						::Process.kill(:HUP, @process_id)
					end
				end
				
				# Reap the child process.
				# @parameter timeout [Numeric | Nil] The maximum time to wait for the process to exit.
				# @returns [::Process::Status | Nil] The process status, or `nil` if the timeout expired.
				def reap(timeout = nil)
					unless @status
						if timeout
							deadline = Deadline.new(timeout)
							
							loop do
								if result = ::Process.waitpid2(@process_id, ::Process::WNOHANG)
									_, @status = result
									break
								elsif deadline.expired?
									return nil
								else
									sleep([deadline.remaining, 0.01].min)
								end
							end
						else
							_, @status = ::Process.waitpid2(@process_id)
						end
					end
					
					return @status
				end
			end
		end
	end
end
