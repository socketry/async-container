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
require "async/container"

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

### Stopping Child Processes

Containers provide three approaches for stopping child processes (or threads). When you call `container.stop()`, a progressive approach is used:

- **Interrupt** means **"Please start shutting down gracefully"**. This is the gentlest shutdown request, giving applications maximum time to finish current work and cleanup resources.

- **Terminate** means **"Shut down now"**. This is more urgent - the process should stop what it's doing and terminate promptly, but still has a chance to cleanup.

- **Kill** means **"Die immediately"**. This forcefully terminates the process with no cleanup opportunity. This is the method of last resort.

The escalation sequence follows this pattern:
1. interrupt → wait for timeout → still running?
2. terminate → wait for timeout → still running? 
3. kill → process terminated.

This gives well-behaved processes multiple opportunities to shut down gracefully, while ensuring that unresponsive processes are eventually killed.

**Implementation Note:** For forked containers, these methods send Unix signals (`SIGINT`, `SIGTERM`, `SIGKILL`). For threaded containers, they use different mechanisms appropriate to threads. The container abstraction hides these implementation details.

## Controllers

The controller provides the life-cycle management for one or more containers of processes. It provides behaviour like starting, restarting, reloading and stopping. You can see some [example implementations in Falcon](https://github.com/socketry/falcon/blob/master/lib/falcon/controller/). If the process running the controller receives `SIGHUP` it will recreate the container gracefully.

``` ruby
require "async/container"

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

### Controller Signal Handling

Controllers are designed to run at the process level and are therefore responsible for processing signals. When your controller process receives these signals:

- `SIGHUP` → Gracefully reload the container (restart with new configuration).
- `SIGINT` → Begin graceful shutdown of the entire controller and all children.
- `SIGTERM` → Begin immediate shutdown of the controller and all children.

Ideally, do not send `SIGKILL` to a controller, as it will immediately terminate the controller without giving it a chance to gracefully shut down child processes. This can leave orphaned processes running and prevent proper cleanup.
