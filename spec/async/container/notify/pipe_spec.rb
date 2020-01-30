# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require "async/container/controller"

RSpec.describe Async::Container::Notify::Pipe do
	let(:notify_script) {File.expand_path("notify.rb", __dir__)}
	
	it "receives notification of child status" do
		container = Async::Container.new
		
		container.spawn(restart: false) do |instance|
			instance.exec(
				"bundle", "exec", "--keep-file-descriptors",
				notify_script, ready: false
			)
		end
		
		# Wait for the state to be updated by the child process:
		container.sleep
		
		child, state = container.state.first
		expect(state).to be == {status: "Initializing..."}
		
		container.wait
		
		expect(container.statistics).to have_attributes(failures: 0)
	end
end
