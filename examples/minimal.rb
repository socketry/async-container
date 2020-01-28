
class Threaded
	def initialize(&block)
		@channel = Channel.new
		@thread = Thread.new(&block)
		
		@waiter = Thread.new do
			begin
				@thread.join
			rescue Exception => error
				finished(error)
			else
				finished
			end
		end
	end
	
	attr :channel
	
	def close
		self.terminate!
		self.wait
	ensure
		@channel.close
	end
	
	def interrupt!
		@thread.raise(Interrupt)
	end
	
	def terminate!
		@thread.raise(Terminate)
	end
	
	def wait
		if @waiter
			@waiter.join
			@waiter = nil
		end
		
		return @status
	end
	
	protected
	
	def finished(error = nil)
		@status = Status.new(error)
		@channel.out.close
	end
end

class Forked
	def initialize(&block)
		@channel = Channel.new
		@status = nil
		
		@pid = Process.fork do
			Signal.trap(:INT) {raise Interrupt}
			Signal.trap(:INT) {raise Terminate}
			
			@channel.in.close
			
			yield
		end
		
		@channel.out.close
	end
	
	attr :channel
	
	def close
		self.terminate!
		self.wait
	ensure
		@channel.close
	end
	
	def interrupt!
		Process.kill(:INT, @pid)
	end
	
	def terminate!
		Process.kill(:TERM, @pid)
	end
	
	def wait
		unless @status
			pid, @status = ::Process.wait(@pid)
		end
		
		return @status
	end
end
