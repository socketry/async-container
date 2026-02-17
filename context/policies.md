# Container Policies

This guide explains how to use policies to monitor container health and implement custom failure handling strategies.

## Motivation

Containers restart failing child processes automatically, but sometimes you need more intelligent behavior:

- **Detect failure patterns**: Repeated segfaults indicate serious bugs that won't fix themselves by restarting.
- **Prevent resource waste**: Stop trying to restart processes that will never succeed.
- **Monitor health**: Track failure rates and alert when thresholds are exceeded.
- **Custom responses**: Implement application-specific logic for different failure types.

Use policies when you need:
- **Segfault detection**: Stop the container after multiple segfaults indicate memory corruption.
- **Failure rate monitoring**: Alert or stop when children fail too frequently.
- **Custom logging**: Track specific failure types for debugging.
- **Graceful degradation**: Give unhealthy children extra time before killing them.

## Default Behavior

Containers use {ruby Async::Container::Policy::DEFAULT} unless you specify otherwise. The default policy:

- Allows children to restart indefinitely if configured with `restart: true`.
- Kills children immediately when health checks fail.
- Kills children immediately when startup timeouts are exceeded.

This is appropriate for most applications, but you can customize it.

## Creating Custom Policies

Policies are Ruby classes that inherit from {ruby Async::Container::Policy} and override callback methods:

``` ruby
require "async/container"

class SegfaultDetectionPolicy < Async::Container::Policy
	def initialize(max_segfaults: 3, window: 60)
		@max_segfaults = max_segfaults
		@segfault_rate = Async::Container::Rate.new(window: window)
	end
	
	def child_exit(container, child, status, name:, key:, **options)
		if segfault?(status)
			@segfault_rate.add(1)
			
			segfault_count = @segfault_rate.total
			
			Console.warn(self, "Segfault detected", 
				name: name, 
				count: segfault_count,
				rate: @segfault_rate.per_minute
			)
		end
		
		# Stop container if too many segfaults
		if segfault_count >= @max_segfaults
			unless container.stopping?
				Console.error(self, "Too many segfaults, stopping container",
					count: segfault_count,
					rate: @segfault_rate.per_second
				)
				container.stop(false)
			end
		end
	end
end

controller = Async::Container::Controller.new 

# Use the custom policy:
def controller.make_policy
	SegfaultDetectionPolicy.new(max_segfaults: 5, window: 120)
end

# ...

controller.run
```

## Policy Callbacks

Policies can implement these callbacks:

### `child_spawn`

Called when a child process starts:

``` ruby
def child_spawn(container, child, name:, key:, **options)
	Console.info(self, "Child started", name: name)
end
```

Use this for tracking which children are running or initializing per-child state.

### `child_exit`

Called when a child process exits (success or failure):

``` ruby
def child_exit(container, child, status, name:, key:, **options)
	if success?(status)
		Console.info(self, "Child succeeded", name: name)
	else
		Console.warn(self, "Child failed", 
			name: name,
			exit_code: exit_code(status),
			signal: signal(status)
		)
	end
end
```

This is the main callback for implementing failure detection logic. You can:
- Track failure rates.
- Detect specific failure types (segfaults, aborts).
- Call `container.stop` to stop the entire container.

### `health_check_failed`

Called when a health check timeout is exceeded. The default implementation logs and kills the child:

``` ruby
def health_check_failed(container, child, age:, timeout:, **options)
	Console.warn(self, "Health check failed", child: child, age: age)
	
	# Send alert before killing
	send_alert("Health check failed for child")
	
	# Call default behavior
	super
end
```

Override this to:
- Send alerts before killing.
- Give children more time (don't kill immediately).
- Implement custom recovery logic.

### `startup_failed`

Called when a startup timeout is exceeded. The default implementation logs and kills the child:

``` ruby
def startup_failed(container, child, age:, timeout:, **options)
	# Custom logging with more context
	Console.error(self, "Child never became ready",
		child: child,
		age: age,
		timeout: timeout
	)
	
	# Kill the child (default behavior)
	super
end
```

## Helper Methods

The {ruby Async::Container::Policy} class provides helper methods for detecting specific failure conditions:

- `segfault?(status)` - Returns true if the process was terminated by SIGSEGV.
- `abort?(status)` - Returns true if the process was terminated by SIGABRT.
- `killed?(status)` - Returns true if the process was terminated by SIGKILL.
- `success?(status)` - Returns true if the process exited successfully.
- `signal(status)` - Returns the signal number that terminated the process.
- `exit_code(status)` - Returns the exit code.
