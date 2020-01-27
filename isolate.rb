
# We define end of life-cycle in terms of "Interrupt" (SIGINT), "Terminate" (SIGTERM) and "Kill" (SIGKILL, does not invoke user code).
class Terminate < Interrupt
end
parent = Isolate.new do |parent|
	preload_user_code
	server = bind_socket
	children = 4.times.map do
		Isolate.new do |worker|
			app = load_user_application
			worker.ready!
			server.accept do |peer|
				app.handle_request(peer)
			end
		end
	end
	while status = parent.wait
		# Status is not just exit status of process but also can be `:ready` or something else.
	end
end
# Similar to Process.wait(pid)
status = parent.wait
# Life cycle controls
parent.interrupt!
parent.terminate!
parent.kill!
