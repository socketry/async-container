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
	end
end
