# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/deadline"
require "set"

module Async
	module Container
		# Tracks a set of children and publishes state-change events.
		class Group
			# Emitted when a child is spawned into the group.
			Spawn = Data.define(:child)
			
			# Emitted when a child sends a notification message.
			Update = Data.define(:child, :message)
			
			# Emitted when a child exits the group.
			Exit = Data.define(:child, :status)
			
			def initialize
				@children = Set.new
				@events = Thread::Queue.new
			end
			
			# @attribute [Set(Child)] The children currently in the group.
			attr :children
			
			# @returns [Set(Child)] The children currently running.
			def running
				@children
			end
			
			# @returns [Integer] The number of children in the group.
			def size
				@children.size
			end
			
			# @returns [Boolean] Whether the group has any children.
			def any?
				@children.any?
			end
			
			# @returns [Boolean] Whether the group has no children.
			def empty?
				@children.empty?
			end
			
			# @returns [Boolean] Whether the group has any children.
			def running?
				any?
			end
			
			# Iterate over the children in the group.
			def each(&block)
				@children.each(&block)
			end
			
			# Add a child to the group.
			def add(child)
				unless @children.add?(child)
					raise ArgumentError, "Child already exists in group: #{child.inspect}"
				end
				
				@events.push(Spawn.new(child))
				
				return child
			end
			
			# Publish a child notification event.
			def update(child, message)
				@events.push(Update.new(child, message))
				
				return child
			end
			
			# Remove a child from the group.
			def remove(child, status = nil)
				unless @children.delete?(child)
					raise ArgumentError, "Child does not exist in group: #{child.inspect}"
				end
				
				@events.push(Exit.new(child, status))
				
				return child
			end
			
			# Wait for group events.
			#
			# If a block is given, events are yielded until the block breaks, the
			# timeout expires, or the event queue closes. If no block is given, a
			# single event is returned.
			def wait(timeout = nil)
				deadline = Deadline.new(timeout) if timeout
				
				loop do
					event = if deadline
						return nil if deadline.expired?
						
						@events.pop(timeout: deadline.remaining)
					else
						@events.pop
					end
					
					return nil unless event
					return event unless block_given?
					
					yield event
				end
			end
			
			# Wait until the group has no children.
			def wait_until_empty(timeout = nil, &block)
				return true if empty?
				
				result = wait(timeout) do |event|
					yield event if block
					break true if empty?
				end
				
				return result == true
			end
			
			# Interrupt all children in the group.
			def interrupt!
				@children.each(&:interrupt!)
			end
			
			# Terminate all children in the group.
			def terminate!
				@children.each(&:terminate!)
			end
			
			# Kill all children in the group.
			def kill!
				@children.each(&:kill!)
			end
			
			# Restart all children in the group.
			def restart!
				@children.each(&:restart!)
			end
			
			# Stop all children in the group without consuming child channels.
			#
			# A graceful shutdown sends interrupts and waits for child owner tasks to
			# remove the children. If a numeric timeout expires, remaining children are
			# killed and the method waits indefinitely for removal. If `graceful` is
			# false, children are killed immediately.
			def stop(graceful = true, &block)
				return true if empty?
				
				if graceful
					interrupt!
					
					timeout = (graceful == true) ? nil : graceful
					return true if wait_until_empty(timeout, &block)
				end
				
				unless empty?
					kill!
					wait_until_empty(nil, &block)
				end
			end
		end
	end
end
