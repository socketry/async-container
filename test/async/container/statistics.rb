# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/statistics"

describe Async::Container::Statistics do
	let(:statistics) {subject.new}
	
	with "#spawn!" do
		it "can count spawns" do
			expect(statistics.spawns).to be == 0
			
			statistics.spawn!
			
			expect(statistics.spawns).to be == 1
		end
	end
	
	with "#restart!" do
		it "can count restarts" do
			expect(statistics.restarts).to be == 0
			
			statistics.restart!
			
			expect(statistics.restarts).to be == 1
		end
	end
	
	with "#failure!" do
		it "can count failures" do
			expect(statistics.failures).to be == 0
			
			statistics.failure!
			
			expect(statistics.failures).to be == 1
		end
	end
	
	with "#failed?" do
		it "can check for failures" do
			expect(statistics).not.to be(:failed?)
			
			statistics.failure!
			
			expect(statistics).to be(:failed?)
		end
	end
	
	with "#<<" do
		it "can append statistics" do
			other = subject.new
			
			other.spawn!
			other.restart!
			other.failure!
			
			statistics << other
			
			expect(statistics.spawns).to be == 1
			expect(statistics.restarts).to be == 1
			expect(statistics.failures).to be == 1
		end
	end
end