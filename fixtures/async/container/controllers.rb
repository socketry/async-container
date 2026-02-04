# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	module Container
		module Controllers
			ROOT = File.join(__dir__, "controllers")
			
			def self.path_for(controller)
				File.join(ROOT, "#{controller}.rb")
			end
		end
		
		AController = Sus::Shared("a controller") do |controller|
			let(:controller_path) {Async::Container::Controllers.path_for(controller)}
			
			let(:pipe) {IO.pipe}
			let(:input) {pipe.first}
			let(:output) {pipe.last}
			
			let(:server) {Async::Container::Notify::Server.open}
			let(:notify_socket) {server.path}
			
			let(:process_id) {@process_id}
			
			before do
				environment = ENV.to_h.merge({"NOTIFY_SOCKET" => notify_socket})
				@notify = server.bind
				
				@process_id = Process.spawn(environment, "bundle", "exec", controller_path, out: output)
				output.close
			end
			
			after do
				if @process_id
					Process.kill(:TERM, @process_id)
					Process.wait(@process_id)
				end
				
				@notify&.close
			end
			
			def wait_until_ready
				@notify.wait_until_ready
			end
		end
	end
end
