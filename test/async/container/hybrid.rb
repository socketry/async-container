# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.

require "async/container/hybrid"
require "async/container/best"
require "async/container/a_container"

describe Async::Container::Hybrid do
	it_behaves_like Async::Container::AContainer
	
	it "should be multiprocess" do
		expect(subject).to be(:multiprocess?)
	end
	
	it "forcefully stops the inner threaded container on exit" do
		stop_arguments = []
		interrupt_count = 0
		
		threaded_class = Class.new
		threaded_class.define_method(:run) do |**options, &block|
			self
		end
		threaded_class.define_method(:wait_until_ready) do
		end
		threaded_class.define_method(:wait) do
			@wait_count ||= 0
			@wait_count += 1
			
			raise Interrupt if @wait_count == 1
		end
		threaded_class.define_method(:interrupt) do
			interrupt_count += 1
		end
		threaded_class.define_method(:stop) do |graceful = true|
			stop_arguments << graceful
		end
		
		container_class = Class.new(subject) do
			def spawn(**options, &block)
				instance = Object.new
				def instance.ready!
				end
				
				block.call(instance)
			end
		end
		
		original_threaded = Async::Container.send(:remove_const, :Threaded)
		Async::Container.const_set(:Threaded, threaded_class)
		
		container = container_class.new
		container.run(count: 1, forks: 1, threads: 1) do |instance|
			# No-op.
		end
		
		expect(interrupt_count).to be == 1
		expect(stop_arguments).to be == [false]
	ensure
		Async::Container.send(:remove_const, :Threaded)
		Async::Container.const_set(:Threaded, original_threaded)
	end
	
	# https://github.com/socketry/async-container/issues/58
	#
	# SIGINT and SIGTERM are intentionally equivalent: both are trapped in the fork and converted into `Interrupt` (see `Forked::Child.fork`), so a single signal of either kind must drain the inner threads and exit, rather than respawning them forever (the inner container has `restart: true`, the default for `async-service` managed services).
	def exits_fork_on_single_signal(signal)
		pids = IO.pipe
		fork_pid = nil
		exited = false
		container = subject.new
		
		container.run(count: 1, forks: 1, threads: 1, restart: true) do |instance|
			pids.last.puts(Process.pid.to_s)
			instance.ready!
			sleep
		end
		
		container.wait_until_ready
		
		fork_pid = Integer(pids.first.gets)
		
		# Mimic a single signal delivered to the fork (e.g. memory-based worker recycling):
		Process.kill(signal, fork_pid)
		
		# The fork must drain its inner threads and exit, rather than respawning them forever:
		8.times do
			reaped, _status = Process.waitpid2(fork_pid, Process::WNOHANG)
			if reaped
				exited = true
				break
			end
			sleep(0.1)
		rescue Errno::ECHILD
			exited = true
			break
		end
		
		expect(exited).to be == true
	ensure
		Process.kill(:KILL, fork_pid) if fork_pid && !exited
		container&.stop
		pids&.each(&:close)
	end
	
	it "exits the fork on a single SIGINT even when the inner container has restart: true" do
		exits_fork_on_single_signal(:INT)
	end
	
	it "exits the fork on a single SIGTERM even when the inner container has restart: true" do
		exits_fork_on_single_signal(:TERM)
	end
end if Async::Container.fork?
