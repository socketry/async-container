# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/statistics"

describe Async::Container::Statistics::Rate do
	let(:rate) {subject.new(window: 10)}
	
	with "#window" do
		it "stores window size" do
			rate = subject.new(window: 30)
			expect(rate.window).to be == 30
		end
		
		it "defaults to 60 second window" do
			rate = subject.new
			expect(rate.window).to be == 60
		end
	end
	
	with "#add" do
		it "can add values to the current slot" do
			rate.add(1, time: 100)
			rate.add(2, time: 100)
			
			expect(rate.total(time: 100)).to be == 3
		end
		
		it "can add values to different slots" do
			rate.add(1, time: 100)
			rate.add(2, time: 101)
			rate.add(3, time: 102)
			
			expect(rate.total(time: 102)).to be == 6
		end
		
		it "resets stale slots" do
			rate.add(5, time: 100)
			
			# Same slot, but after window has passed
			rate.add(3, time: 120)
			
			expect(rate.total(time: 120)).to be == 3
		end
	end
	
	with "#total" do
		it "sums values within the window" do
			rate.add(1, time: 100)
			rate.add(2, time: 101)
			rate.add(3, time: 102)
			
			expect(rate.total(time: 105)).to be == 6
		end
		
		it "excludes values outside the window" do
			rate.add(1, time: 100)
			rate.add(2, time: 101)
			rate.add(3, time: 102)
			
			# At time 112, values from time 100 and 101 are outside the 10-second window
			expect(rate.total(time: 112)).to be == 3
		end
		
		it "returns zero when all values are stale" do
			rate.add(1, time: 100)
			rate.add(2, time: 101)
			
			expect(rate.total(time: 200)).to be == 0
		end
	end
	
	with "#per_second" do
		it "calculates rate per second" do
			# Add 10 events over 10 seconds
			10.times do |i|
				rate.add(1, time: 100 + i)
			end
			
			expect(rate.per_second(time: 109)).to be == 1.0
		end
		
		it "handles partial windows" do
			# Add 5 events
			5.times do |i|
				rate.add(1, time: 100 + i)
			end
			
			# 5 events / 10 second window = 0.5 per second
			expect(rate.per_second(time: 104)).to be == 0.5
		end
	end
	
	with "#per_minute" do
		it "calculates rate per minute" do
			# Add 10 events
			10.times do |i|
				rate.add(1, time: 100 + i)
			end
			
			expect(rate.per_minute(time: 109)).to be == 60.0
		end
	end
	
	with "sliding window behavior" do
		it "maintains accurate counts as time progresses" do
			# Add events at different times
			rate.add(1, time: 100)
			rate.add(1, time: 101)
			rate.add(1, time: 102)
			
			expect(rate.total(time: 105)).to be == 3
			
			# Add more events later
			rate.add(1, time: 108)
			rate.add(1, time: 109)
			
			expect(rate.total(time: 109)).to be == 5
			
			# At time 112, events from 100-101 are outside window
			expect(rate.total(time: 112)).to be == 3
			
			# At time 120, all original events are outside window
			expect(rate.total(time: 120)).to be == 0
		end
	end
end

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
	
	with "rate tracking" do
		let(:statistics) {subject.new(window: 10)}
		
		it "tracks restart rate" do
			3.times{statistics.restart!}
			
			expect(statistics.restart_rate.total).to be >= 3
			expect(statistics.restart_rate.per_second).to be > 0
		end
		
		it "tracks failure rate" do
			5.times{statistics.failure!}
			
			expect(statistics.failure_rate.total).to be >= 5
			expect(statistics.failure_rate.per_second).to be > 0
		end
		
		it "includes rates in JSON output" do
			statistics.restart!
			statistics.failure!
			
			json = statistics.as_json
			
			expect(json).to have_keys(:spawns, :restarts, :failures, :restart_rate, :failure_rate)
			expect(json[:restarts]).to be == 1
			expect(json[:failures]).to be == 1
			expect(json[:restart_rate]).to be_a(Float)
			expect(json[:failure_rate]).to be_a(Float)
		end
	end
end
