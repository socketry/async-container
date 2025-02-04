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
