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

module Async
	module Container
		module Notify
			class Client
				def self.open(path = ENV['NOTIFY_SOCKET'], pid: Process.pid)
					if path
						self.new(path, pid)
					end
				end
				
				def initialize(path, pid)
					@path = path
					@pid = pid
				end
				
				def send(message)
					socket = Addrinfo.unix(@path, Socket::SOCK_DGRAM).connect
					
					socket.write(message)
				ensure
					socket&.close
				end
				
				def ready!
					send("READY=1")
				end
				
				def reloading!
					send("RELOADING=1")
				end
				
				def stopping!
					send("STOPPING=1")
				end
				
				def status!(text)
					send("STATUS=#{text}")
				end
				
				def error!(text, errno = -1)
					send("STATUS=#{text}\nERRNO=#{text}")
				end
			end
			
			class Server
				def initialize(path)
					@path = path
				end
				
				def accept
					socket = Addrinfo.unix(@path, Socket::SOCK_DGRAM).bind
					
					while true
						peer = socket.accept
						
						
					end
				ensure
					socket&.close
				end
			end
		end
	end
end
