

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
			ensure
				@channel.close
			end
		end
	end
	
	def wait
		
	end
	
	protected
	
	def finished(error = nil)
		@status = Status.new(error)
		@channel.close_write
	end
end

class Forked
	def initialize(&block)
		@channel = Channel.new
		
		@pid = Process.fork(&block)
		
		@channel.close_write
	end
	
	protected
	
	
end