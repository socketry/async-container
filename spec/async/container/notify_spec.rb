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

RSpec.describe Async::Container::Notify do
	let(:server) {described_class::Server.open}
	let(:notify_socket) {server.path}
	let(:client) {described_class::Client.open(notify_socket)}
	
	describe '#ready!' do
		it "should send message" do
			begin
				context = server.bind
				
				pid = fork do
					client.ready!
				end
				
				Sync do
					context.receive do |message, address|
						break if context.ready?([pid])
					end
				end
				
				expect(context.status[pid]).to be == "Ready..."
				expect(context.state[pid]).to be :ready
			ensure
				context&.close
				Process.wait(pid) if pid
			end
		end
	end
end
