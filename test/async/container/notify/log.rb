# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.
# Copyright, 2020, by Olle Jonsson.

require "async/container/controller"
require "async/container/controllers"

require "tmpdir"

describe Async::Container::Notify::Pipe do
	let(:notify_script) {Async::Container::Controllers.path_for("notify")}
	let(:notify_log) {File.expand_path("notify-#{::Process.pid}-#{SecureRandom.hex(8)}.log", Dir.tmpdir)}
	
	it "receives notification of child status" do
		system({"NOTIFY_LOG" => notify_log}, "bundle", "exec", notify_script)
		
		lines = File.readlines(notify_log).map{|line| JSON.parse(line)}
		
		expect(lines.last).to be == {"ready" => true}
	end
end
