# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.
# Copyright, 2020, by Juan Antonio Martín Lucas.

require_relative "client"

require "json"

module Async
	module Container
		module Notify
			# Implements a process readiness protocol using an inherited pipe file descriptor.
			class Pipe < Client
				# The environment variable key which contains the pipe file descriptor.
				NOTIFY_PIPE = "NOTIFY_PIPE"
				
				# Open a notification client attached to the current {NOTIFY_PIPE} if possible.
				def self.open!(environment = ENV)
					if descriptor = environment.delete(NOTIFY_PIPE)
						self.new(::IO.for_fd(descriptor.to_i))
					end
				rescue Errno::EBADF => error
					Console.error(self) {error}
					
					return nil
				end
				
				# Initialize the notification client.
				# @parameter io [IO] An IO instance used for sending messages.
				def initialize(io)
					@io = io
				end
				
				# Inserts or duplicates the environment given an argument array.
				# Sets or clears it in a way that is suitable for {::Process.spawn}.
				def before_spawn(arguments, options)
					environment = environment_for(arguments)
					
					# Use `notify_pipe` option if specified:
					if notify_pipe = options.delete(:notify_pipe)
						options[notify_pipe] = @io
						environment[NOTIFY_PIPE] = notify_pipe.to_s
						
					# Use stdout if it's not redirected:
					# This can cause issues if the user expects stdout to be connected to a terminal.
					# elsif !options.key?(:out)
					# 	options[:out] = @io
					# 	environment[NOTIFY_PIPE] = "1"
						
					# Use fileno 3 if it's available:
					elsif !options.key?(3)
						options[3] = @io
						environment[NOTIFY_PIPE] = "3"
						
					# Otherwise, give up!
					else
						raise ArgumentError, "Please specify valid file descriptor for notify_pipe!"
					end
				end
				
				# Formats the message using JSON and sends it to the parent controller.
				# This is suitable for use with {Channel}.
				def send(**message)
					data = ::JSON.dump(message) << "\n"
					
					@io.write(data)
					@io.flush
				end
				
				private
				
				def environment_for(arguments)
					# Insert or duplicate the environment hash which is the first argument:
					if arguments.first.is_a?(Hash)
						environment = arguments[0] = arguments.first.dup
					else
						arguments.unshift(environment = Hash.new)
					end
					
					return environment
				end
			end
		end
	end
end
