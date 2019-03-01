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

require_relative 'container/forked'
require_relative 'container/threaded'
require_relative 'container/hybrid'

require 'etc'

module Async
	# Containers execute one or more "instances" which typically contain a reactor. A container spawns "instances" using threads and/or processes. Because these are resources that must be cleaned up some how (either by `join` or `waitpid`), their creation is deferred until the user invokes `Container#wait`. When executed this way, the container guarantees that all "instances" will be complete once `Container#wait` returns. Containers are constructs for achieving parallelism, and are not designed to be used directly for concurrency. Typically, you'd create one or more container, add some tasks to it, and then wait for it to complete.
	module Container
		def self.run(concurrency_class: Threaded, **options, &block)
			concurrency_class.run(**options, &block)
		end
		
		def self.processor_count
			Etc.nprocessors
		rescue
			2
		end
	end
end
