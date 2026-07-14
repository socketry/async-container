# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "sus/shared"
require "sus/fixtures/async/scheduler_context"
require "tmpdir"
require "fileutils"

module Async
	module Container
		AContainer = Sus::Shared("a container") do
			include Sus::Fixtures::Async::SchedulerContext
			
			let(:container) {subject.new}
			
			def temporary_directory
				path = Dir.mktmpdir("async-container")
				
				begin
					yield path
				ensure
					FileUtils.remove_entry(path)
				end
			end
			
			def append_line(path, line)
				File.open(path, "a") do |file|
					file.flock(File::LOCK_EX)
					file.puts(line)
				end
			end
			
			def read_lines(path)
				File.exist?(path) ? File.readlines(path, chomp: true) : []
			end
			
			def exited_or_reaped?(pid)
				!!Process.waitpid2(pid, Process::WNOHANG)
			rescue Errno::ECHILD
				true
			end
			
			it "spawns a child and observes readiness" do
				container.spawn(name: "worker") do |instance|
					instance.ready!(status: "ready")
					sleep
				end
				
				expect(container.wait_until_ready).to be == true
				expect(container).to be(:running?)
				expect(container.state.values.any?{|state| state[:ready] == true && state[:status] == "ready"}).to be == true
				
				container.stop(false)
				
				expect(container).not.to be(:running?)
			end
			
			it "runs the requested number of workers" do
				temporary_directory do |directory|
					path = File.join(directory, "workers.log")
					
					container.run(count: 2) do |instance|
						append_line(path, "ready")
						instance.ready!
						sleep
					end
					
					expect(container.wait_until_ready).to be == true
					expect(read_lines(path).size).to be == 2
				ensure
					container.stop(false)
				end
			end
			
			it "runs asynchronous work" do
				temporary_directory do |directory|
					path = File.join(directory, "async.log")
					
					container.async do
						append_line(path, "done")
					end
					
					container.wait
					
					expect(read_lines(path)).to be == ["done"]
					expect(container.statistics.failures).to be == 0
				end
			end
			
			it "waits for children to exit normally" do
				container.spawn do |instance|
					instance.ready!
				end
				
				container.wait
				
				expect(container).not.to be(:running?)
				expect(container.statistics).to have_attributes(spawns: be == 1, failures: be == 0)
				expect(container).not.to be(:failed?)
			end
			
			it "records child failures" do
				container.spawn do
					raise "boom"
				end
				
				container.wait
				
				expect(container).not.to be(:running?)
				expect(container.statistics).to have_attributes(spawns: be == 1, failures: be == 1)
				expect(container).to be(:failed?)
			end
			
			it "can stop gracefully" do
				container.spawn do |instance|
					instance.ready!
					sleep
				rescue Interrupt
					# Graceful shutdown.
				end
				
				expect(container.wait_until_ready).to be == true
				
				container.stop(true)
				
				expect(container).not.to be(:running?)
				expect(container.statistics.failures).to be == 0
			end
			
			it "can stop immediately" do
				container.spawn do |instance|
					instance.ready!
					sleep
				end
				
				expect(container.wait_until_ready).to be == true
				
				container.stop(false)
				
				expect(container).not.to be(:running?)
			end
			
			it "restarts failed children when requested" do
				temporary_directory do |directory|
					marker_path = File.join(directory, "started")
					
					container.spawn(restart: true) do |instance|
						if File.exist?(marker_path)
							instance.ready!
							sleep
						else
							File.write(marker_path, "started")
							raise "boom"
						end
					end
					
					expect(container.wait_until_ready).to be == true
					
					container.stop(false)
					
					expect(container.statistics).to have_attributes(spawns: be == 2, restarts: be == 1, failures: be == 1)
				ensure
					container.stop(false)
				end
			end
			
			it "does not spawn a duplicate keyed child" do
				expect(container.spawn(key: :worker) do |instance|
					instance.ready!
					sleep
				end).to be == true
				
				expect(container.wait_until_ready).to be == true
				expect(container.spawn(key: :worker){sleep}).to be == false
				expect(container[:worker]).not.to be_nil
				
				container.stop(false)
			end
			
			it "stops children when the lifecycle task is cancelled" do
				next unless subject.multiprocess?
				
				reader, writer = IO.pipe
				
				owner = Async::Task.current.async do |task|
					container.spawn(parent: task) do
						writer.puts(Process.pid)
						sleep
					end
					
					sleep
				end
				
				child_pid = reader.gets.to_i
				
				owner.cancel
				owner.wait rescue nil
				container.wait
				
				expect(exited_or_reaped?(child_pid)).to be == true
			ensure
				reader&.close unless reader&.closed?
				writer&.close unless writer&.closed?
				
				if child_pid
					begin
						Process.kill(:KILL, child_pid)
						Process.wait(child_pid)
					rescue Errno::ECHILD, Errno::ESRCH
					end
				end
			end
		end
	end
end
