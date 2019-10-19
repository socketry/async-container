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

require 'async/reactor'

require 'etc'

module Async
	module Container
		# @return [Integer] the number of hardware processors which can run threads/processes simultaneously.
		def self.processor_count
			Etc.nprocessors
		rescue
			2
		end
		
		class Generic
			def initialize
				@statistics = Statistics.new
			end
			
			attr :statistics
			
			def failed?
				@statistics.failed?
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
		end
	end
end
