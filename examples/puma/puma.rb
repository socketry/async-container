on_booted do
	require "async/container/notify"
	
	notify = Async::Container::Notify.open!
	notify&.ready!
end
