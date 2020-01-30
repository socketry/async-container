# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'async'

require 'etc'

require_relative 'group'
require_relative 'keyed'
require_relative 'statistics'

module Async
	module Container
		# @return [Integer] the number of hardware processors which can run threads/processes simultaneously.
		def self.processor_count
			Etc.nprocessors
		rescue
			2
		end
		
		class Generic
			def self.run(*arguments, **options, &block)
				self.new.run(*arguments, **options, &block)
			end
			
			UNNAMED = "Unnamed"
			
			def initialize(**options)
				@group = Group.new
				@running = true
				
				@state = {}
				
				@statistics = Statistics.new
				@keyed = {}
			end
			
			def to_s
				"#{self.class} with #{@statistics.spawns} spawns and #{@statistics.failures} failures."
			end
			
			def [] key
				@keyed[key]&.value
			end
			
			attr :statistics
			
			def failed?
				@statistics.failed?
			end
			
			# Whether there are running tasks.
			def running?
				@group.running?
			end
			
			# Sleep until some state change occurs.
			# @param duration [Integer] the maximum amount of time to sleep for.
			def sleep(duration = nil)
				@group.sleep(duration)
			end
			
			# Wait until all spawned tasks are completed.
			def wait
				@group.wait
			end
			
			def status?(flag)
				# This also returns true if all processes have exited/failed:
				@state.all?{|_, state| state[flag]}
			end
			
			def wait_until_ready
				while true
					Async.logger.debug(self) do |buffer|
						buffer.puts "Waiting for ready:"
						@state.each do |child, state|
							buffer.puts "\t#{child.class}: #{state.inspect}"
						end
					end
					
					self.sleep
					
					if self.status?(:ready)
						return true
					end
				end
			end
			
			def stop(timeout = true)
				@running = false
				@group.stop(timeout)
				
				if @group.running?
					Async.logger.warn(self) {"Group is still running after stopping it!"}
				end
			ensure
				@running = true
			end
			
			def spawn(name: nil, restart: false, key: nil, &block)
				name ||= UNNAMED
				
				if mark?(key)
					Async.logger.debug(self) {"Reusing existing child for #{key}: #{name}"}
					return false
				end
				
				@statistics.spawn!
				
				Fiber.new do
					while @running
						child = self.start(name, &block)
						
						state = insert(key, child)
						
						begin
							status = @group.wait_for(child) do |message|
								state.update(message)
							end
						ensure
							delete(key, child)
						end
						
						if status.success?
							Async.logger.info(self) {"#{child} #{status}"}
						else
							@statistics.failure!
							Async.logger.error(self) {status}
						end
						
						if restart
							@statistics.restart!
						else
							break
						end
					end
				# ensure
				# 	Async.logger.error(self) {$!} if $!
				end.resume
				
				return true
			end
			
			def async(**options, &block)
				spawn(**options) do |instance|
					Async::Reactor.run(instance, &block)
				end
			end
			
			def run(count: Container.processor_count, **options, &block)
				count.times do
					spawn(**options, &block)
				end
				
				return self
			end
			
			def reload
				@keyed.each_value(&:clear!)
				
				yield
				
				dirty = false
				
				@keyed.delete_if do |key, value|
					value.stop? && (dirty = true)
				end
				
				return dirty
			end
			
			def mark?(key)
				if key
					if value = @keyed[key]
						value.mark!
						
						return true
					end
				end
				
				return false
			end
			
			def key?(key)
				if key
					@keyed.key?(key)
				end
			end
			
			protected
			
			# Register the child (value) as running.
			def insert(key, child)
				if key
					@keyed[key] = Keyed.new(key, child)
				end
				
				state = {}
				
				@state[child] = state
				
				return state
			end
			
			# Clear the child (value) as running.
			def delete(key, child)
				if key
					@keyed.delete(key)
				end
				
				@state.delete(child)
			end
		end
	end
end
