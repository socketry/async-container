# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2020, by Samuel Williams.

require "async/container/controller"

RSpec.describe Async::Container::Controller do
	describe '#reload' do
		it "can reuse keyed child" do
			input, output = IO.pipe
			
			subject.instance_variable_set(:@output, output)
			
			def subject.setup(container)
				container.spawn(key: "test") do |instance|
					instance.ready!
					
					sleep(0.2 * QUANTUM)
					
					@output.write(".")
					@output.flush
					
					sleep(0.4 * QUANTUM)
				end
				
				container.spawn do |instance|
					instance.ready!
					
					sleep(0.3 * QUANTUM)
					
					@output.write(",")
					@output.flush
				end
			end
			
			subject.start
			expect(input.read(2)).to be == ".,"
			
			subject.reload
			
			expect(input.read(1)).to be == ","
			subject.wait
		end
	end
	
	describe '#start' do
		it "can start up a container" do
			expect(subject).to receive(:setup)
			
			subject.start
			
			expect(subject).to be_running
			expect(subject.container).to_not be_nil
			
			subject.stop
			
			expect(subject).to_not be_running
			expect(subject.container).to be_nil
		end
		
		it "can spawn a reactor" do
			def subject.setup(container)
				container.async do |task|
					task.sleep 1
				end
			end
			
			subject.start
			
			statistics = subject.container.statistics
			
			expect(statistics.spawns).to be == 1
			
			subject.stop
		end
		
		it "propagates exceptions" do
			def subject.setup(container)
				raise "Boom!"
			end
			
			expect do
				subject.run
			end.to raise_exception(Async::Container::SetupError)
		end
	end
	
	context 'with signals' do
		let(:controller_path) {File.expand_path("dots.rb", __dir__)}
		
		let(:pipe) {IO.pipe}
		let(:input) {pipe.first}
		let(:output) {pipe.last}
		
		let(:pid) {Process.spawn("bundle", "exec", controller_path, out: output)}
		
		before do
			pid
			output.close
		end
		
		after do
			Process.kill(:KILL, pid)
		end
		
		it "restarts children when receiving SIGHUP" do
			expect(input.read(1)).to be == '.'
			
			Process.kill(:HUP, pid)
			
			expect(input.read(2)).to be == 'I.'
		end
		
		it "exits gracefully when receiving SIGINT" do
			expect(input.read(1)).to be == '.'
			
			Process.kill(:INT, pid)
			
			expect(input.read).to be == 'I'
		end
		
		it "exits gracefully when receiving SIGTERM" do
			expect(input.read(1)).to be == '.'
			
			Process.kill(:TERM, pid)
			
			expect(input.read).to be == 'T'
		end
	end
end
