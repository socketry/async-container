# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Udi Oron.

require "async/container/threaded"
require "async/container/forked"
require "async/container/best"

# Collect what each worker reports about its own ordinal.
def collect_worker_ordinals(container, count: 3, **options)
	input, output = IO.pipe
	container.run(count: count, **options) do |instance|
		output.write("#{instance.ordinal}\n")
	end
	container.wait
	output.close
	input.read.lines.map(&:to_i)
ensure
	input&.close unless input&.closed?
end

describe Async::Container::Generic do
	let(:container) {Async::Container::Threaded.new}
	
	with "#acquire_ordinal" do
		it "assigns sequential ordinals starting at 0" do
			expect(container.send(:acquire_ordinal)).to be == 0
			expect(container.send(:acquire_ordinal)).to be == 1
			expect(container.send(:acquire_ordinal)).to be == 2
		end
		
		it "reuses the lowest released ordinal before extending the range" do
			3.times{container.send(:acquire_ordinal)}   # => 0, 1, 2
			container.send(:release_ordinal, 1)
			
			expect(container.send(:acquire_ordinal)).to be == 1   # reused
			expect(container.send(:acquire_ordinal)).to be == 3   # then extends
		end
		
		it "does not hand out the same ordinal twice when an ordinal is released more than once" do
			2.times{container.send(:acquire_ordinal)}   # => 0, 1
			container.send(:release_ordinal, 0)
			container.send(:release_ordinal, 0)          # double release must be idempotent
			
			expect(container.send(:acquire_ordinal)).to be == 0   # the recycled ordinal
			expect(container.send(:acquire_ordinal)).to be == 2   # not 0 again
		end
	end
	
	with "keyed reuse" do
		it "does not allocate an ordinal for a reused keyed child" do
			container.spawn(key: :web){sleep}   # allocates 0, registers the key
			reused = container.spawn(key: :web){sleep}   # mark? hit => returns before allocating
			
			expect(reused).to be == false
			# If the second spawn had allocated, the next free ordinal would be 2:
			expect(container.send(:acquire_ordinal)).to be == 1
		ensure
			container.stop(false)
		end
	end
	
	with "injected ordinals" do
		it "does not accept an ordinal option via run" do
			expect do
				container.run(count: 2, ordinal: 7){sleep}
			end.to raise_exception(ArgumentError, message: be =~ /unknown keyword: :ordinal/)
		end
	end
end

describe Async::Container::Threaded do
	let(:container) {subject.new}
	
	it "exposes instance.ordinal to the worker" do
		ordinals = collect_worker_ordinals(container, count: 3)
		
		expect(ordinals.sort).to be == [0, 1, 2]
		expect(container.statistics).to have_attributes(failures: be == 0)
	end
	
	it "preserves instance.ordinal across a restart" do
		trigger = IO.pipe
		ordinals = IO.pipe
		
		runner = Thread.new do
			container.spawn(restart: true) do |instance|
				ordinals.last.puts(instance.ordinal.to_s)
				trigger.first.gets   # block until told to exit, then the worker restarts
			end
			container.wait
		end
		
		reported = []
		2.times do
			reported << ordinals.first.gets.to_i
			trigger.last.puts("die")
		end
		
		runner.kill
		runner.join
		
		# Same ordinal allocated for both incarnations (ordinal is captured outside the restart loop):
		expect(reported).to be == [reported.first, reported.first]
	end
end

describe Async::Container::Forked do
	let(:container) {subject.new}
	
	it "exposes instance.ordinal to the worker" do
		ordinals = collect_worker_ordinals(container, count: 3)
		
		expect(ordinals.sort).to be == [0, 1, 2]
		expect(container.statistics).to have_attributes(failures: be == 0)
	end
end if Async::Container.fork?
