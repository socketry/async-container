# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "../child"
require_relative "instance"

module Async
	module Container
		module Forked
			class Child < Container::Child
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
