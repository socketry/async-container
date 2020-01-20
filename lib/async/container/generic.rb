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
			UNNAMED = "Unnamed"
			
			def initialize
				@statistics = Statistics.new
				@keyed = {}
			end
			
			attr :statistics
			
			def failed?
				@statistics.failed?
			end
			
			# Wait until all spawned tasks are completed.
			def wait
			end
			
			def spawn(name: nil, restart: false, key: nil)
				name ||= UNNAMED
				
				return if mark?(key)
				
				@statistics.spawn!
				
				Fiber.new do
					while true
						child = self.start(name) do |instance|
							yield instance
						end
						
						insert(key, child)
						
						begin
							# child.wait -> Fiber.yield
							status = child.wait
						ensure
							delete(key)
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
				end.resume
				
				return self
			end
			
			def async(**options, &block)
				spawn(**options) do |instance|
					begin
						Async::Reactor.run(instance, &block)
					rescue Interrupt
						# Graceful exit.
					end
				end
			end
			
			def run(count: Container.processor_count, **options, &block)
				count.times do
					async(**options, &block)
				end
				
				return self
			end
			
			def reload
				@keyed.each_value(&:clear!)
				
				yield
				
				@keyed.delete_if do |key, value|
					value.stop?
				end
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
			
			def compact!
				@keyed.delete_if do |key, value|
					!value.marked?
				end
			end
			
			def key?(key)
				if key
					@keyed.key?(key)
				end
			end
			
			def delete(key)
				if key
					if value = @keyed.delete(key)
						value.stop
					end
				end
			end
			
			protected
			
			def insert(key, value)
				if key
					@keyed[key] = Keyed.new(key, value)
				end
			end
		end
	end
end
