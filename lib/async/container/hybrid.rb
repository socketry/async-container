# frozen_string_literal: true

# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative 'forked'
require_relative 'threaded'

module Async
	module Container
		# Provides a hybrid multi-process multi-thread container.
		class Hybrid < Forked
			# Run multiple instances of the same block in the container.
			# @parameter count [Integer] The number of instances to start.
			# @parameter forks [Integer] The number of processes to fork.
			# @parameter threads [Integer] the number of threads to start.
			def run(count: nil, forks: nil, threads: nil, **options, &block)
				processor_count = Container.processor_count
				count ||= processor_count ** 2
				forks ||= [processor_count, count].min
				threads = (count / forks).ceil
				
				forks.times do
					self.spawn(**options) do |instance|
						container = Threaded.new
						
						container.run(count: threads, **options, &block)
						
						container.wait_until_ready
						instance.ready!
						
						container.wait
					rescue Async::Container::Terminate
						# Stop it immediately:
						container.stop(false)
					ensure
						# Stop it gracefully (also code path for Interrupt):
						container.stop
					end
				end
				
				return self
			end
		end
	end
end
