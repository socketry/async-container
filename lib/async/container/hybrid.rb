# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require_relative "forked"
require_relative "threaded"

module Async
	module Container
		class Hybrid < Generic
			def initialize(*arguments, **options)
				super(Forked::Child, *arguments, **options)
			end
			
			def run(count: nil, forks: nil, threads: nil, health_check_timeout: nil, **options, &block)
				processor_count = Async::Container.processor_count
				count ||= processor_count ** 2
				forks ||= [processor_count, count].min
				threads ||= (count / forks).ceil
				
				forks.times do
					spawn(**options) do |instance|
						container = Threaded.new
						
						container.run(count: threads, health_check_timeout: health_check_timeout, **options, &block)
						container.wait_until_ready
						
						instance.ready!
						
						begin
							container.wait
						rescue Interrupt
							container.interrupt
							retry
						end
					ensure
						container&.stop(false)
					end
				end
				
				return self
			end
			
			def self.multiprocess?
				true
			end
		end
	end
end
