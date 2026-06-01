# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Udi Oron.

require "async/container/threaded"
require "async/container/forked"
require "async/container/best"

# Collect what each worker reports about its own instance context.
def collect_worker_context(container, count: 3, **options)
	input, output = IO.pipe
	container.run(count: count, **options) do |instance|
		output.write("#{instance.num}:#{instance.kind}\n")
	end
	container.wait
	output.close
	input.read.lines.map(&:chomp)
ensure
	input&.close unless input&.closed?
end

describe Async::Container::Generic do
	let(:container) {Async::Container::Threaded.new}

	with "#acquire_instance_num" do
		it "assigns sequential nums starting at 0" do
			expect(container.send(:acquire_instance_num)).to be == 0
			expect(container.send(:acquire_instance_num)).to be == 1
			expect(container.send(:acquire_instance_num)).to be == 2
		end

		it "reuses the lowest released num before extending the range" do
			3.times {container.send(:acquire_instance_num)}   # => 0, 1, 2
			container.send(:release_instance_num, 1)

			expect(container.send(:acquire_instance_num)).to be == 1   # reused
			expect(container.send(:acquire_instance_num)).to be == 3   # then extends
		end

		it "does not hand out the same num twice when a num is released more than once" do
			2.times {container.send(:acquire_instance_num)}   # => 0, 1
			container.send(:release_instance_num, 0)
			container.send(:release_instance_num, 0)          # double release must be idempotent

			expect(container.send(:acquire_instance_num)).to be == 0   # the recycled num
			expect(container.send(:acquire_instance_num)).to be == 2   # not 0 again
		end
	end

	with "keyed reuse" do
		it "does not allocate a num for a reused keyed child" do
			container.spawn(key: :web) {sleep}   # allocates 0, registers the key
			reused = container.spawn(key: :web) {sleep}   # mark? hit => returns before allocating

			expect(reused).to be == false
			# If the second spawn had allocated, the next free num would be 2:
			expect(container.send(:acquire_instance_num)).to be == 1
		ensure
			container.stop(false)
		end
	end
end

describe Async::Container::Threaded do
	let(:container) {subject.new}

	it "exposes instance.num and instance.kind to the worker (kind: :thread)" do
		reported = collect_worker_context(container, count: 3)

		nums = reported.map {|line| line.split(":").first.to_i}
		kinds = reported.map {|line| line.split(":").last}.uniq

		expect(nums.sort).to be == [0, 1, 2]
		expect(kinds).to be == ["thread"]
		expect(container.statistics).to have_attributes(failures: be == 0)
	end

	it "preserves instance.num across a restart" do
		trigger = IO.pipe
		nums = IO.pipe

		runner = Thread.new do
			container.spawn(restart: true) do |instance|
				nums.last.puts(instance.num.to_s)
				trigger.first.gets   # block until told to exit, then the worker restarts
			end
			container.wait
		end

		reported = []
		2.times do
			reported << nums.first.gets.to_i
			trigger.last.puts("die")
		end

		runner.kill
		runner.join

		# Same num allocated for both incarnations (num is captured outside the restart loop):
		expect(reported).to be == [reported.first, reported.first]
	end
end

describe Async::Container::Forked do
	let(:container) {subject.new}

	it "exposes instance.num and instance.kind to the worker (kind: :process)" do
		reported = collect_worker_context(container, count: 3)

		nums = reported.map {|line| line.split(":").first.to_i}
		kinds = reported.map {|line| line.split(":").last}.uniq

		expect(nums.sort).to be == [0, 1, 2]
		expect(kinds).to be == ["process"]
		expect(container.statistics).to have_attributes(failures: be == 0)
	end
end if Async::Container.fork?
