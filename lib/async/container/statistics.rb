# frozen_string_literal: true

# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

module Async
	module Container
		# Tracks various statistics relating to child instances in a container.
		class Statistics
			def initialize
				@spawns = 0
				@restarts = 0
				@failures = 0
			end
			
			# How many child instances have been spawned.
			# @attribute [Integer]
			attr :spawns
			
			# How many child instances have been restarted.
			# @attribute [Integer]
			attr :restarts
			
			# How many child instances have failed.
			# @attribute [Integer]
			attr :failures
			
			# Increment the number of spawns by 1.
			def spawn!
				@spawns += 1
			end
			
			# Increment the number of restarts by 1.
			def restart!
				@restarts += 1
			end
			
			# Increment the number of failures by 1.
			def failure!
				@failures += 1
			end
			
			# Whether there have been any failures.
			# @returns [Boolean] If the failure count is greater than 0.
			def failed?
				@failures > 0
			end
			
			# Append another statistics instance into this one.
			# @parameter other [Statistics] The statistics to append.
			def << other
				@spawns += other.spawns
				@restarts += other.restarts
				@failures += other.failures
			end
		end
	end
end
