# Getting Started

This guide explains how to use `async-container` to build basic scalable systems.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add async-container
~~~

## Core Concepts

`async-container` has several core concepts:

- {ruby Async::Container::Forked} and {ruby Async::Container::Threaded} are used to manage one or more child processes and threads respectively for parallel execution. While threads share the address space which can reduce overall memory usage, processes have better isolation and fault tolerance.
- {ruby Async::Container::Controller} manages one or more containers and handles graceful restarts. Containers should be implemented in such a way that multiple containers can be running at the same time.

## Containers

A container represents a set of child processes (or threads) which are doing work for you.

``` ruby
require 'async/container'

Console.logger.debug!

container = Async::Container.new

container.spawn do |task|
	Console.debug task, "Sleeping..."
	sleep(1)
	Console.debug task, "Waking up!"
end

Console.debug "Waiting for container..."
container.wait
Console.debug "Finished."
```

## Controllers

The controller provides the life-cycle management for one or more containers of processes. It provides behaviour like starting, restarting, reloading and stopping. You can see some [example implementations in Falcon](https://github.com/socketry/falcon/blob/master/lib/falcon/controller/). If the process running the controller receives `SIGHUP` it will recreate the container gracefully.

``` ruby
require 'async/container'

Console.logger.debug!

class Controller < Async::Container::Controller
	def create_container
		Async::Container::Forked.new
		# or Async::Container::Threaded.new
		# or Async::Container::Hybrid.new
	end
	 
	def setup(container)
		container.run count: 2, restart: true do |instance|
			while true
				Console.debug(instance, "Sleeping...")
				sleep(1)
			end
		end
	end
end

controller = Controller.new

controller.run

# If you send SIGHUP to this process, it will recreate the container.
```

## Signal Handling

`SIGINT` is the interrupt signal. The terminal sends it to the foreground process when the user presses **ctrl-c**. The default behavior is to terminate the process, but it can be caught or ignored. The intention is to provide a mechanism for an orderly, graceful shutdown.

`SIGQUIT` is the dump core signal. The terminal sends it to the foreground process when the user presses **ctrl-\\**. The default behavior is to terminate the process and dump core, but it can be caught or ignored. The intention is to provide a mechanism for the user to abort the process. You can look at `SIGINT` as "user-initiated happy termination" and `SIGQUIT` as "user-initiated unhappy termination."

`SIGTERM` is the termination signal. The default behavior is to terminate the process, but it also can be caught or ignored. The intention is to kill the process, gracefully or not, but to first allow it a chance to cleanup.

`SIGKILL` is the kill signal. The only behavior is to kill the process, immediately. As the process cannot catch the signal, it cannot cleanup, and thus this is a signal of last resort.

`SIGSTOP` is the pause signal. The only behavior is to pause the process; the signal cannot be caught or ignored. The shell uses pausing (and its counterpart, resuming via `SIGCONT`) to implement job control.

## Integration

### systemd

Install a template file into `/etc/systemd/system/`:

```
# my-daemon.service
[Unit]
Description=My Daemon
AssertPathExists=/srv/

[Service]
Type=notify
WorkingDirectory=/srv/my-daemon
ExecStart=bundle exec my-daemon
Nice=5

[Install]
WantedBy=multi-user.target
```
