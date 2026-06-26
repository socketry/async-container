# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Udi Oron.

require "async/container/threaded"
require "async/container/forked"
require "async/container/hybrid"
require "async/container/ordinals"
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
	
	with "ordinal allocation" do
		it "assigns sequential ordinals starting at 0" do
			ordinals = collect_worker_ordinals(container, count: 3)
			
			expect(ordinals.sort).to be == [0, 1, 2]
		end
		
		it "reuses the lowest released ordinal before extending the range" do
			first = collect_worker_ordinals(container, count: 3)
			second = collect_worker_ordinals(container, count: 1)
			
			expect(first.sort).to be == [0, 1, 2]
			expect(second).to be == [0]
		end
	end
	
	with "keyed reuse" do
		it "does not allocate an ordinal for a reused keyed child" do
			input, output = IO.pipe
			
			container.spawn(key: :web) do |instance|
				output.puts(instance.ordinal)
				sleep
			end
			
			expect(input.gets.to_i).to be == 0
			
			reused = container.spawn(key: :web){sleep}   # mark? hit => returns before allocating
			
			expect(reused).to be == false
			expect(container.instance_variable_get(:@ordinals).acquire).to be == 1
		ensure
			container.stop(false)
			input&.close unless input&.closed?
			output&.close unless output&.closed?
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

describe Async::Container::Ordinals::Sequential do
	let(:ordinals) {subject.new}
	
	it "assigns sequential ordinals starting at 0" do
		expect(ordinals.acquire).to be == 0
		expect(ordinals.acquire).to be == 1
		expect(ordinals.acquire).to be == 2
	end
	
	it "can start at an initial ordinal" do
		ordinals = subject.new(10)
		
		expect(ordinals.acquire).to be == 10
		expect(ordinals.acquire).to be == 11
	end
	
	it "reuses the lowest released ordinal before extending the range" do
		3.times{ordinals.acquire}   # => 0, 1, 2
		ordinals.release(1)
		
		expect(ordinals.acquire).to be == 1   # reused
		expect(ordinals.acquire).to be == 3   # then extends
	end
	
	it "does not hand out the same ordinal twice when an ordinal is released more than once" do
		2.times{ordinals.acquire}   # => 0, 1
		ordinals.release(0)
		ordinals.release(0)         # double release must be idempotent
		
		expect(ordinals.acquire).to be == 0   # the recycled ordinal
		expect(ordinals.acquire).to be == 2   # not 0 again
	end
	
	it "reserves ordinals as a fixed allocator" do
		reserved = ordinals.reserve(3)
		
		expect(reserved).to be_a(Async::Container::Ordinals::Fixed)
		expect(reserved.to_a).to be == [0, 1, 2]
		expect(ordinals.acquire).to be == 3
	end
end

describe Async::Container::Ordinals::Fixed do
	let(:ordinals) {subject.new([5, 7])}
	
	it "creates a fixed allocator from a range" do
		ordinals = subject.range(5, 3)
		
		expect(ordinals.to_a).to be == [5, 6, 7]
	end
	
	it "allocates from the fixed pool" do
		expect(ordinals.acquire).to be == 5
		expect(ordinals.acquire).to be == 7
		expect{ordinals.acquire}.to raise_exception(Async::Container::Ordinals::Exhausted)
	end
	
	it "can release ordinals back to the fixed pool" do
		expect(ordinals.acquire).to be == 5
		ordinals.release(5)
		expect(ordinals.acquire).to be == 5
	end
	
	it "reserves ordinals as a fixed allocator" do
		reserved = ordinals.reserve(2)
		
		expect(reserved).to be_a(Async::Container::Ordinals::Fixed)
		expect(reserved.to_a).to be == [5, 7]
		expect{ordinals.acquire}.to raise_exception(Async::Container::Ordinals::Exhausted)
	end
	
	it "does not partially reserve ordinals if the pool is too small" do
		expect{ordinals.reserve(3)}.to raise_exception(Async::Container::Ordinals::Exhausted)
		
		expect(ordinals.acquire).to be == 5
		expect(ordinals.acquire).to be == 7
	end
	
	it "rejects ordinals outside the fixed pool" do
		expect{ordinals.release(6)}.to raise_exception(ArgumentError)
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
	
	it "does not inherit ordinals into independently managed child containers" do
		input, output = IO.pipe
		
		container.run(count: 1) do |instance|
			child = subject.new
			child_ordinals = collect_worker_ordinals(child, count: 2)
			
			output.puts("outer=#{instance.ordinal} child=#{child_ordinals.sort.join(",")}")
		end
		
		container.wait
		output.close
		reported = input.read.lines.map(&:chomp)
		
		expect(reported).to be == ["outer=0 child=0,1"]
	ensure
		input&.close unless input&.closed?
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

describe Async::Container::Hybrid do
	let(:container) {subject.new}
	
	it "assigns unique worker ordinals across forked threaded workers" do
		ordinals = collect_worker_ordinals(container, count: 4, forks: 2, threads: 2)
		
		expect(ordinals.sort).to be == [0, 1, 2, 3]
		expect(container.statistics).to have_attributes(failures: be == 0)
	end
	
	it "anchors worker ordinal ranges to the fork ordinal" do
		container = subject.new(ordinals: Async::Container::Ordinals::Sequential.new(3))
		ordinals = collect_worker_ordinals(container, count: 4, forks: 2, threads: 2)
		
		expect(ordinals.sort).to be == [6, 7, 8, 9]
		expect(container.statistics).to have_attributes(failures: be == 0)
	end
end if Async::Container.fork?
