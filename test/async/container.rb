# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2025, by Samuel Williams.

require "async/container"
require "open3"
require "rbconfig"

describe Async::Container do
	def ruby(script)
		::Open3.capture3(::RbConfig.ruby, "-Ilib", "-e", script)
	end
	
	def expect_success(script)
		stdout, stderr, status = ruby(script)
		
		expect(status).to be(:success?)
		expect(stderr).to be == ""
		
		return stdout
	end
	
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
	
	with ".new" do
		let(:container) {Async::Container.new}
		
		it "can get best container class" do
			expect(container).not.to be_nil
			container.stop
		end
	end
	
	with "graceful signal defaults" do
		it "installs graceful SIGINT handling" do
			stdout = expect_success(<<~RUBY)
				require "async/container"
				
				begin
					::Thread.handle_interrupt(::Interrupt => :never) do
						::Process.kill(:INT, ::Process.pid)
						puts "inner"
					end
					
					sleep 1
				rescue ::Interrupt
					puts "outer"
				end
			RUBY
			
			expect(stdout).to be == "inner\nouter\n"
		end
		
		it "installs graceful SIGTERM handling" do
			stdout = expect_success(<<~RUBY)
				require "async/container"
				
				begin
					::Thread.handle_interrupt(::Interrupt => :never) do
						::Process.kill(:TERM, ::Process.pid)
						puts "inner"
					end
					
					sleep 1
				rescue ::Interrupt
					puts "outer"
				end
			RUBY
			
			expect(stdout).to be == "inner\nouter\n"
		end
	end
	
	with ".best" do
		it "can get the best container class" do
			expect(Async::Container.best_container_class).not.to be_nil
		end
		
		it "can get the best container class if fork is not available" do
			expect(subject).to receive(:fork?).and_return(false)
			
			expect(Async::Container.best_container_class).to be == Async::Container::Threaded
		end
	end
end
