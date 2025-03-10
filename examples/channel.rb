# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.
# Copyright, 2020, by Olle Jonsson.

require "json"

class Channel
	def initialize
		@in, @out = IO.pipe
	end
	
	def after_fork
		@out.close
	end
	
	def receive
		if data = @in.gets
			JSON.parse(data, symbolize_names: true)
		end
	end
	
	def send(**message)
		data = JSON.dump(message)
		
		@out.puts(data)
	end
end

status = Channel.new

pid = fork do
	status.send(ready: false, status: "Initializing...")
	
	# exit(-1) # crash
	
	status.send(ready: true, status: "Initialization Complete!")
end

status.after_fork

while message = status.receive
	pp message
end

pid, status = Process.waitpid2(pid)

puts "Status: #{status}"
