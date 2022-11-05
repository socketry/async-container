# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2020, by Samuel Williams.

require "async/container"

RSpec.describe Async::Container do
	describe '.processor_count' do
		it "can get processor count" do
			expect(Async::Container.processor_count).to be >= 1
		end
		
		it "can override the processor count" do
			env = {'ASYNC_CONTAINER_PROCESSOR_COUNT' => '8'}
			
			expect(Async::Container.processor_count(env)).to be == 8
		end
		
		it "fails on invalid processor count" do
			env = {'ASYNC_CONTAINER_PROCESSOR_COUNT' => '-1'}
			
			expect do
				Async::Container.processor_count(env)
			end.to raise_error(/Invalid processor count/)
		end
	end
	
	it "can get best container class" do
		expect(Async::Container.best_container_class).to_not be_nil
	end
	
	subject {Async::Container.new}
	
	it "can get best container class" do
		expect(subject).to_not be_nil
		
		subject.stop
	end
end
