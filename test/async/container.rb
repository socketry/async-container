# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2024, by Samuel Williams.

require "async/container"

describe Async::Container do
	with ".processor_count" do
		it "can get processor count" do
			expect(Async::Container.processor_count).to be >= 1
		end
		
		it "can override the processor count" do
			env = {"ASYNC_CONTAINER_PROCESSOR_COUNT" => "8"}
			
			expect(Async::Container.processor_count(env)).to be == 8
		end
		
		it "fails on invalid processor count" do
			env = {"ASYNC_CONTAINER_PROCESSOR_COUNT" => "-1"}
			
			expect do
				Async::Container.processor_count(env)
			end.to raise_exception(RuntimeError, message: be =~ /Invalid processor count/)
		end
	end
	
	it "can get best container class" do
		expect(Async::Container.best_container_class).not.to be_nil
	end
	
	with ".new" do
		let(:container) {Async::Container.new}
		
		it "can get best container class" do
			expect(container).not.to be_nil
			container.stop
		end
	end
end
