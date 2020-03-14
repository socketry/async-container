# frozen_string_literal: true

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

require_relative 'channel'
require_relative 'notify/pipe'

require 'async/logger'

module Async
	module Container
		class Thread < Channel
			class Exit < Exception
				def initialize(status)
					@status = status
				end
				
				attr :status
				
				def error
					unless status.success?
						status
					end
				end
			end
			
			class Instance < Notify::Pipe
				def self.for(thread)
					self.new(thread.out)
				end
				
				def initialize(io)
					@name = nil
					@thread = ::Thread.current
					
					super
				end
				
				def name= value
					@thread.name = value
				end
				
				def name
					@thread.name
				end
				
				def exec(*arguments, ready: true, **options)
					if ready
						self.ready!(status: "(spawn)") if ready
					else
						self.before_spawn(arguments, options)
					end
					
					begin
						# TODO prefer **options... but it doesn't support redirections on < 2.7
						pid = ::Process.spawn(*arguments, options)
					ensure
						_, status = ::Process.wait2(pid)
						
						raise Exit, status
					end
				end
			end
			
			def self.fork(**options)
				self.new(**options) do |thread|
					::Thread.new do
						yield Instance.for(thread)
					end
				end
			end
			
			def initialize(name: nil)
				super()
				
				@status = nil
				
				@thread = yield(self)
				@thread.report_on_exception = false
				@thread.name = name
				
				@waiter = ::Thread.new do
					begin
						@thread.join
					rescue Exit => exit
						finished(exit.error)
					rescue Interrupt
						# Graceful shutdown.
						finished
					rescue Exception => error
						finished(error)
					else
						finished
					end
				end
			end
			
			def name= value
				@thread.name = name
			end
			
			def name
				@thread.name
			end
			
			def to_s
				"\#<#{self.class} #{@thread.name}>"
			end
			
			def close
				self.terminate!
				self.wait
			ensure
				super
			end
			
			def interrupt!
				@thread.raise(Interrupt)
			end
			
			def terminate!
				@thread.raise(Terminate)
			end
			
			def wait
				if @waiter
					@waiter.join
					@waiter = nil
				end
				
				@status
			end
			
			class Status
				def initialize(result = nil)
					@result = result
				end
				
				def success?
					@result.nil?
				end
				
				def to_s
					"\#<#{self.class} #{success? ? "success" : "failure"}>"
				end
			end
			
			protected
			
			def finished(error = nil)
				if error
					Async.logger.error(self) {error}
				end
				
				@status = Status.new(error)
				self.close_write
			end
		end
	end
end
