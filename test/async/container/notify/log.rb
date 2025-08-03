# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/container/controller"
require "async/container/controllers"

require "tmpdir"
require "bake"

describe Async::Container::Notify::Log do
	let(:notify_script) {Async::Container::Controllers.path_for("notify")}
	let(:notify_log) {File.expand_path("notify-#{::Process.pid}-#{SecureRandom.hex(8)}.log", Dir.tmpdir)}
	let(:notify) {Async::Container::Notify::Log.open!({"NOTIFY_LOG" => notify_log})}
	
	after do
		File.unlink(notify_log) rescue nil
	end

	it "receives notification of child status" do
		system({"NOTIFY_LOG" => notify_log}, "bundle", "exec", notify_script)
		
		lines = File.readlines(notify_log).map{|line| JSON.parse(line)}
		
		expect(lines.last).to have_keys(
			"ready" => be == true,
			"size" => be > 0,
		)
	end

	with "async:container:notify:log:ready?" do
		let(:context) {Bake::Context.load}
		let(:recipe) {context.lookup("async:container:notify:log:ready?")}

		it "fails if the log file does not exist" do
			expect do
				recipe.call(path: "nonexistant.log")
			end.to raise_exception(RuntimeError, message: be =~ /log file does not exist/i)
		end

		it "succeeds if the log file exists and is ready" do
			notify.ready!

			expect(recipe.call(path: notify_log)).to be == true
		end

		it "fails if the log file exists but is not ready" do
			notify.status!("Loading...")
			
			expect do
				expect(recipe.call(path: notify_log))
			end.to raise_exception(RuntimeError, message: be =~ /service is not ready/i)
		end
	end
end
