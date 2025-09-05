# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

def initialize(...)
	super
	
	require "async/container/notify/log"
end

# Check if the log file exists and the service is ready.
# @parameter path [String] The path to the notification log file, uses the `NOTIFY_LOG` environment variable if not provided.
def ready?(path: Async::Container::Notify::Log.path)
	if File.exist?(path)
		File.foreach(path) do |line|
			message = JSON.parse(line)
			if message["ready"] == true
				return true
			end
		end
		
		raise "Service is not ready yet."
	else
		raise "Notification log file does not exist at #{path}"
	end
end
