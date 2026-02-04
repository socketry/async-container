# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.

require "async/container/controller"
require "async/container/controllers"

describe Async::Container::Controller do
	let(:controller) {subject.new}
	
	with "#to_s" do
		it "can generate string representation" do
			expect(controller.to_s).to be == "Async::Container::Controller stopped"
		end
	end
	
	with "#reload" do
		it "can reuse keyed child" do
			input, output = IO.pipe
			
			controller.instance_variable_set(:@output, output)
			
			def controller.setup(container)
				container.spawn(key: "test") do |instance|
					instance.ready!
					
					@output.write(".")
					@output.flush
					
					sleep(0.2)
				end
				
				container.spawn do |instance|
					instance.ready!
					
					sleep(0.1)
					
					@output.write(",")
					@output.flush
				end
			end
			
			controller.start
			
			expect(controller.state_string).to be == "running"
			
			expect(input.read(2)).to be == ".,"
			
			controller.reload
			
			expect(input.read(1)).to be == ","
			
			controller.wait
		end
	end
	
	with "#start" do
		it "can start up a container" do
			expect(controller).to receive(:setup)
			
			controller.start
			
			expect(controller).to be(:running?)
			expect(controller.container).not.to be_nil
			
			controller.stop
			
			expect(controller).not.to be(:running?)
			expect(controller.container).to be_nil
		end
		
		it "can spawn a reactor" do
			def controller.setup(container)
				container.async do |task|
					task.sleep 0.001
				end
			end
			
			controller.start
			
			statistics = controller.container.statistics
			
			expect(statistics.spawns).to be == 1
			
			controller.stop
		end
		
		it "propagates exceptions" do
			def controller.setup(container)
				raise "Boom!"
			end
			
			expect do
				controller.run
			end.to raise_exception(Async::Container::SetupError)
		end
	end
	
	with "graceful controller" do
		let(:controller_path) {Async::Container::Controllers.path_for("graceful")}
		
		let(:pipe) {IO.pipe}
		let(:input) {pipe.first}
		let(:output) {pipe.last}
		
		let(:pid) {@pid}
		
		def before
			@pid = Process.spawn("bundle", "exec", controller_path, out: output)
			output.close
			
			super
		end
		
		def after(error = nil)
			Process.kill(:TERM, @pid)
			Process.wait(@pid)
			
			super
		end
		
		it "has graceful shutdown" do
			expect(input.gets).to be == "Ready...\n"
			
			Process.kill(:INT, @pid)
			
			expect(input.gets).to be == "Exiting...\n"
		end
	end
	
	with "bad controller" do
		let(:controller_path) {Async::Container::Controllers.path_for("bad")}
		
		let(:pipe) {IO.pipe}
		let(:input) {pipe.first}
		let(:output) {pipe.last}
		
		let(:pid) {@pid}
		
		def before
			@pid = Process.spawn("bundle", "exec", controller_path, out: output)
			output.close
			
			super
		end
		
		def after(error = nil)
			Process.kill(:TERM, @pid)
			Process.wait(@pid)
			
			super
		end
		
		it "fails to start" do
			expect(input.gets).to be == "Ready...\n"
			
			Process.kill(:INT, @pid)
			
			# It was killed:
			expect(input.gets).to be_nil
		end
	end
	
	with "signals" do
		let(:controller_path) {Async::Container::Controllers.path_for("dots")}
		
		let(:pipe) {IO.pipe}
		let(:input) {pipe.first}
		let(:output) {pipe.last}
		
		let(:pid) {@pid}
		
		def before
			@pid = Process.spawn("bundle", "exec", controller_path, out: output)
			output.close
			
			super
		end
		
		def after(error = nil)
			Process.kill(:TERM, @pid)
			Process.wait(@pid)
			
			super
		end
		
		it "restarts children when receiving SIGHUP" do
			expect(input.read(1)).to be == "."
			
			Process.kill(:HUP, pid)
			
			# The ordering between the old child writing "I" and the new child writing "." is timing-dependent (blue-green restart starts the new container before stopping the old one). Accept either order.
			expect(input.read(2)).to (be == "I.").or(be == ".I")
		end
		
		it "exits gracefully when receiving SIGINT" do
			expect(input.read(1)).to be == "."
			
			Process.kill(:INT, pid)
			
			expect(input.read).to be == "I"
		end
		
		it "exits gracefully when receiving SIGTERM" do
			expect(input.read(1)).to be == "."
			
			Process.kill(:TERM, pid)
			
			# SIGTERM now behaves like SIGINT (graceful)
			expect(input.read).to be == "I"
		end
	end
	
	with "working directory" do
		let(:controller_path) {Async::Container::Controllers.path_for("working_directory")}
		
		it "can change working directory" do
			pipe = IO.pipe
			
			pid = Process.spawn("bundle", "exec", controller_path, out: pipe.last)
			pipe.last.close
			
			expect(pipe.first.gets(chomp: true)).to be == "/"
		ensure
			Process.kill(:INT, pid) if pid
		end
	end
end
