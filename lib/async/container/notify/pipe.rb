# frozen_string_literal: true
#
# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative 'client'

module Async
	module Container
		module Notify
			class Pipe < Client
				NOTIFY_PIPE = 'NOTIFY_PIPE'
				
				def self.open!(environment = ENV)
					if descriptor = environment.delete(NOTIFY_PIPE)
						self.new(::IO.for_fd(descriptor.to_i))
					end
				end
				
				def initialize(io)
					@io = io
				end
				
				def before_exec(environment = ENV)
					environment[NOTIFY_PIPE] = @io.fileno
				end
				
				# Inserts or duplicates the environment given an argument array.
				# Sets or clears it in a way that is suitable for {::Process.spawn}.
				def self.before_spawn(server, arguments)
					if arguments.first.is_a?(Hash)
						environment = arguments.first = arguments.first.dup
					else
						arguments.unshift(environment = Hash.new)
					end
					
					before_exec(arguments.first)
					
					return arguments
				end
				
				def send(**message)
					data = JSON.dump(message)
					
					@io.puts(data)
				end
				
				def ready!(**message)
					send(ready: true, **message)
				end
				
				def reloading!(**message)
					message[:ready] = false
					message[:reloading] = true
					message[:status] ||= "Reloading..."
					
					send(**message)
				end
				
				def reloading!(**message)
					message[:ready] = false
					message[:reloading] = true
					message[:status] ||= "Reloading..."
					
					send(**message)
				end
			end
		end
	end
end
