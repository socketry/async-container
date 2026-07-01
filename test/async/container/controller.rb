# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2026, by Samuel Williams.

require "async/container/controller"
require "async/container/controllers"
require "async/container/notify/server"
require "async/container/notify/socket"

describe Async::Container::Controller do
	let(:controller) {subject.new}
	
	with "#to_s" do
		it "can generate string representation" do
			expect(controller.to_s).to be == "Async::Container::Controller stopped"
		end
	end
	
	with "#graceful_stop" do
		def read_graceful_stop(value)
			command = [
				"bundle", "exec", "ruby", "-Ilib", "-e",
				"require 'async/container/controller'; puts Async::Container::Controller.new(notify: nil).graceful_stop.inspect"
			]
			
			output = IO.popen({"ASYNC_CONTAINER_GRACEFUL_STOP" => value}, command, &:read)
			
			expect($?.success?).to be == true
			
			return output
		end
		
		it "uses the configured graceful timeout by default" do
			output = read_graceful_stop("0.001")
			
			expect(output).to be == "0.001\n"
		end
		
		it "can disable graceful stop by default" do
			output = read_graceful_stop("false")
			
			expect(output).to be == "false\n"
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
	
	with "#restart" do
		it "replaces the running container with a new one" do
			def controller.setup(container)
				container.spawn do |instance|
					instance.ready!
					sleep
				end
			end
			
			controller.start
			first = controller.container
			
			expect(first).not.to be_nil
			expect(controller).to be(:running?)
			
			# A restart is a blue-green swap: a new container is created and the old one is stopped.
			controller.restart
			
			expect(controller.container).not.to be_equal(first)
			expect(controller).to be(:running?)
		ensure
			controller.stop(false)
		end
		
		it "starts a new container if not already running" do
			def controller.setup(container)
				container.spawn do |instance|
					instance.ready!
					sleep
				end
			end
			
			expect(controller).not.to be(:running?)
			
			controller.restart
			
			expect(controller).to be(:running?)
			expect(controller.container).not.to be_nil
		ensure
			controller.stop(false)
		end
	end
	
	with "notify" do
		before do
			@notify_server = Async::Container::Notify::Server.open
			@notify_client = Async::Container::Notify::Socket.new(@notify_server.path)
			@notify = @notify_server.bind
		end
		
		after do
			@notify&.close
		end
		
		let(:controller) {subject.new(notify: @notify_client)}
		
		it "sends status with ready notification on reload" do
			def controller.setup(container)
				container.spawn do |instance|
					instance.ready!
					sleep(0.1)
				end
			end
			
			controller.start
			
			# Drain the start ready message:
			@notify.wait_until_ready
			
			controller.reload
			
			# Capture messages until we find the reload ready notification:
			while message = @notify.receive
				break if message[:ready]
			end
			
			expect(message).to have_keys(
				ready: be == true,
				status: be =~ /Running/
			)
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
		
		it "doesn't restart a container if it's already running" do
			expect(controller).to receive(:setup)
			
			expect(controller.start).to be == true
			expect(controller).to be(:running?)
			
			container = controller.container
			
			# Starting again is idempotent: it returns false and the container is not replaced.
			expect(controller.start).to be == false
			expect(controller.container).to be_equal(container)
		ensure
			controller.stop
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
		include_context Async::Container::AController, "graceful"
		
		it "has graceful shutdown" do
			expect(input.gets).to be == "Ready...\n"
			
			wait_until_ready
			
			Process.kill(:INT, process_id)
			
			expect(input.gets).to be == "Exiting...\n"
		end
		
		it "sends status with ready notification on start" do
			expect(input.gets).to be == "Ready...\n"
			
			# Capture messages until we receive the ready notification:
			while message = @notify.receive
				break if message[:ready]
			end
			
			expect(message).to have_keys(
				ready: be == true,
				status: be =~ /Running/
			)
		end
	end
	
	with "bad controller" do
		include_context Async::Container::AController, "bad"
		
		it "fails to start" do
			expect(input.gets).to be == "Ready...\n"
			
			Process.kill(:INT, process_id)
			
			# It was killed:
			expect(input.gets).to be_nil
		end
	end
	
	with "signals" do
		include_context Async::Container::AController, "dots"
		
		it "restarts children when receiving SIGHUP" do
			expect(input.read(1)).to be == "."
			
			wait_until_ready
			
			Process.kill(:HUP, process_id)
			
			# The ordering between the old child writing "I" and the new child writing "." is timing-dependent (blue-green restart starts the new container before stopping the old one). Accept either order.
			expect(input.read(2)).to (be == "I.").or(be == ".I")
		end
		
		it "exits gracefully when receiving SIGINT" do
			expect(input.read(1)).to be == "."
			
			wait_until_ready
			
			Process.kill(:INT, process_id)
			
			expect(input.read).to be == "I"
		end
		
		it "exits gracefully when receiving SIGTERM" do
			expect(input.read(1)).to be == "."
			
			wait_until_ready
			
			Process.kill(:TERM, process_id)
			
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
