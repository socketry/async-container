# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require "async/container/hybrid"
require "async/container/best"
require "async/container/a_container"

describe Async::Container::Hybrid do
	it_behaves_like Async::Container::AContainer
	
	it "should be multiprocess" do
		expect(subject).to be(:multiprocess?)
	end
	
	it "forcefully stops the inner threaded container on exit" do
		stop_arguments = []
		interrupt_count = 0
		
		threaded_class = Class.new
		threaded_class.define_method(:run) do |**options, &block|
			self
		end
		threaded_class.define_method(:wait_until_ready) do
		end
		threaded_class.define_method(:wait) do
			@wait_count ||= 0
			@wait_count += 1
			
			raise Interrupt if @wait_count == 1
		end
		threaded_class.define_method(:interrupt) do
			interrupt_count += 1
		end
		threaded_class.define_method(:stop) do |graceful = true|
			stop_arguments << graceful
		end
		
		container_class = Class.new(subject) do
			def spawn(**options, &block)
				instance = Object.new
				def instance.ready!
				end
				
				block.call(instance)
			end
		end
		
		original_threaded = Async::Container.send(:remove_const, :Threaded)
		Async::Container.const_set(:Threaded, threaded_class)
		
		container = container_class.new
		container.run(count: 1, forks: 1, threads: 1) do |instance|
			# No-op.
		end
		
		expect(interrupt_count).to be == 1
		expect(stop_arguments).to be == [false]
	ensure
		Async::Container.send(:remove_const, :Threaded)
		Async::Container.const_set(:Threaded, original_threaded)
	end
end if Async::Container.fork?
