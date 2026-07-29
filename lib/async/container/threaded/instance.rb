# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require_relative "../notify/pipe"

module Async
	module Container
		module Threaded
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
				# Wrap an instance around the {Channel} instance from within the threaded child.
				# @parameter channel [Channel] The channel to use for communication.
				# @parameter name [String] The name of the thread.
				def self.for(channel, name: nil)
					instance = self.new(channel.out)
					instance.name = name
					
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
					# Always set up the notification pipe to be inherited by the spawned process.
					self.before_spawn(arguments, options)
					
					if ready
						self.ready!(status: "(spawn)")
					end
					
					begin
						pid = ::Process.spawn(*arguments, **options)
					ensure
						_, status = ::Process.wait2(pid)
						
						raise Exit, status
					end
				end
			end
		end
	end
end
