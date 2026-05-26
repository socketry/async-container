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
end if Async::Container.fork?

describe Async::Container::Hybrid do
	# Pin the inner per-fork ensure-block contract without actually forking: override
	# `#spawn` so the block runs in-process and stub `Threaded.new` so the inner
	# `#stop` call can be observed. The parent `Group#stop(graceful)` is the
	# authoritative deadline for fork exit (`Forked::Child.wait(timeout)` then
	# `kill!`); the inner per-fork shutdown must therefore impose no deadline of
	# its own, otherwise the two budgets race when configured equally.
	with "inner per-fork shutdown timing" do
		let(:inner_stop_calls) {[]}
		
		let(:threaded_double) do
			double = Object.new
			stops = inner_stop_calls
			double.define_singleton_method(:run){|**|}
			double.define_singleton_method(:wait_until_ready){}
			double.define_singleton_method(:wait){raise Interrupt}
			double.define_singleton_method(:stop){|arg = :__no_arg__| stops << arg}
			double
		end
		
		let(:fake_instance) do
			instance = Object.new
			instance.define_singleton_method(:ready!){}
			instance
		end
		
		def run_hybrid_inline(hybrid, instance:)
			hybrid.define_singleton_method(:spawn) do |**options, &block|
				begin
					block.call(instance)
				rescue Interrupt
					# Swallow: simulates the forked process exiting on Interrupt.
				end
			end
			hybrid.run(forks: 1, threads: 1, count: 1){}
		end
		
		def with_threaded_stubbed(double)
			original = Async::Container::Threaded.method(:new)
			Async::Container::Threaded.singleton_class.send(:define_method, :new){|*, **, &| double}
			begin
				yield
			ensure
				Async::Container::Threaded.singleton_class.send(:remove_method, :new)
				Async::Container::Threaded.singleton_class.send(:define_method, :new, original)
			end
		end
		
		it "drains the inner Threaded container without imposing its own deadline" do
			with_threaded_stubbed(threaded_double) do
				hybrid = Async::Container::Hybrid.new
				run_hybrid_inline(hybrid, instance: fake_instance)
			end
			
			expect(inner_stop_calls).to be == [Float::INFINITY]
		end
	end
end if Async::Container.fork?
