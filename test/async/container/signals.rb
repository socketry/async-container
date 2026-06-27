# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/container/signals"

describe Async::Container::Signals do
	let(:events) {::Thread::Queue.new}
	let(:signals) {subject.new(events)}
	
	with Async::Container::Signals::Event do
		it "calls the handler" do
			applied = false
			
			event = Async::Container::Signals::Event.new(:USR1, proc{applied = true})
			
			expect(event.signal).to be == :USR1
			
			event.call
			
			expect(applied).to be == true
		end
	end
	
	with Async::Container::Events do
		let(:events) {Async::Container::Events.new}
		
		it "wakes IO.select when an event is queued" do
			event = Object.new
			
			events << event
			
			readable, _, _ = IO.select([events.io], nil, nil, 0)
			
			expect(readable).to be == [events.io]
			expect(events.pop(timeout: 0)).to be == event
		end
		
		it "returns nil when no event is queued" do
			expect(events.pop(timeout: 0)).to be_nil
		end
	end
	
	with "#events" do
		it "exposes the event queue" do
			expect(signals.events).to be == events
		end
	end
	
	with "#wait" do
		it "waits for queued events" do
			event = Async::Container::Signals::Event.new(:USR1, proc{})
			
			events << event
			
			expect(signals.wait).to be == event
		end
	end
	
	with "#trapped" do
		it "queues trapped signal events" do
			applied = false
			
			signals.trap(:USR1) do
				applied = true
			end
			
			signals.trapped do
				::Process.kill(:USR1, ::Process.pid)
				
				event = signals.wait
				
				expect(event.signal).to be == :USR1
				
				event.call
			end
			
			expect(applied).to be == true
		end
		
		it "reuses a frozen event for trapped signals" do
			signals.trap(:USR1){}
			
			signals.trapped do
				::Process.kill(:USR1, ::Process.pid)
				event = signals.wait
				
				expect(event.frozen?).to be == true
				
				::Process.kill(:USR1, ::Process.pid)
				expect(signals.wait).to be == event
			end
		end
		
		it "ignores signals without a handler" do
			signals.trap(:USR1)
			
			signals.trapped do
				::Process.kill(:USR1, ::Process.pid)
				
				expect do
					events.pop(true)
				end.to raise_exception(ThreadError)
			end
		end
		
		it "can ignore signals explicitly" do
			signals.ignore(:USR1)
			
			signals.trapped do
				::Process.kill(:USR1, ::Process.pid)
				
				expect do
					events.pop(true)
				end.to raise_exception(ThreadError)
			end
		end
		
		it "restores previous signal handlers" do
			previous = ::Thread::Queue.new
			original = ::Signal.trap(:USR1) do
				previous << :handled
			end
			
			begin
				signals.ignore(:USR1)
				
				signals.trapped do
					::Process.kill(:USR1, ::Process.pid)
					
					expect do
						previous.pop(true)
					end.to raise_exception(ThreadError)
				end
				
				::Process.kill(:USR1, ::Process.pid)
				
				expect(previous.pop).to be == :handled
			ensure
				::Signal.trap(:USR1, original)
			end
		end
	end
end
