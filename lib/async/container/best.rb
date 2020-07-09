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

require_relative 'forked'
require_relative 'threaded'
require_relative 'hybrid'

module Async
	module Container
		# Whether the underlying process supports fork.
		# @returns [Boolean]
		def self.fork?
			::Process.respond_to?(:fork) && ::Process.respond_to?(:setpgid)
		end
		
		# Determins the best container class based on the underlying Ruby implementation.
		# Some platforms, including JRuby, don't support fork. Applications which just want a reasonable default can use this method.
		# @returns [Class]
		def self.best_container_class
			if fork?
				return Forked
			else
				return Threaded
			end
		end
		
		# Create an instance of the best container class.
		# @returns [Generic] Typically an instance of either {Forked} or {Threaded} containers.
		def self.new(*arguments, **options)
			best_container_class.new(*arguments, **options)
		end
	end
end
