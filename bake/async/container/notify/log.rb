
def initialize(...)
	super
	
	require "async/container/notify/log"
end

# Check if the log file exists and the service is ready.
def ready?(path: Async::Container::Notify::Log.path)
	if File.exist?(path)
		File.foreach(path) do |line|
			message = JSON.parse(line)
			if message["ready"] == true
				$stderr.puts "Service is ready: #{line}"
				return true
			end
		end
		
		raise "Service is not ready yet."
	else
		raise "Notification log file does not exist at #{path}"
	end
end
