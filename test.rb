# frozen_string_literal: true

Thread.handle_interrupt(RuntimeError => :never) do
	Thread.current.raise(RuntimeError, "Queued error")
	
	puts "Pending interrupt: #{Thread.pending_interrupt?}" # true
	
	pid = Process.fork do
		puts "Pending interrupt (child process): #{Thread.pending_interrupt?}"
		Thread.handle_interrupt(RuntimeError => :immediate){}
	end
	
	_, status = Process.waitpid2(pid)
	puts "Child process status: #{status.inspect}"
	
	puts "Pending interrupt: #{Thread.pending_interrupt?}" # false
end

puts "Exiting..."
