# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.
# Copyright, 2020, by Olle Jonsson.

require "async/container/controller"
require "async/container/controllers"

describe Async::Container::Notify::Pipe do
	let(:notify_script) {Async::Container::Controllers.path_for("notify")}
	
	it "receives notification of child status" do
		container = Async::Container.new
		
		container.spawn(restart: false) do |instance|
			instance.exec(
				"bundle", "exec",
				notify_script, ready: false
			)
		end
		
		# Wait for the state to be updated by the child process:
		container.sleep
		
		_child, state = container.state.first
		expect(state).to be == {status: "Initializing controller..."}
		
		container.wait
		
		expect(container.statistics).to have_attributes(failures: be == 0)
	end
end
