# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Samuel Williams.

require 'kernel/sync'

class Worker
	def initialize(&block)
		
	end
end

Sync do
	count.times do
		worker = Worker.new(&block)
		
		status = worker.wait do |message|
			
		end
		
		status.success?
		status.failed?
	end
end
