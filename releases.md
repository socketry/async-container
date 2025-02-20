# Releases

## Unreleased

  - Fix compatibility between {ruby Async::Container::Hybrid} and the health check.
  - {ruby Async::Container::Generic#initialize} passes unused arguments through to {ruby Async::Container::Group}.

## v0.20.0


  - Improve container signal handling reliability by using `Thread.handle_interrupt` except at known safe points.
  - Improved logging when child process fails and container startup.

### Add `health_check_timeout` for detecting hung processes.

In order to detect hung processes, a `health_check_timeout` can be specified when spawning children workers. If the health check does not complete within the specified timeout, the child process is killed.

```ruby
require "async/container"

container = Async::Container.new

container.run(count: 1, restart: true, health_check_timeout: 1) do |instance|
	while true
		# This example will fail sometimes:
		sleep(0.5 + rand)
		instance.ready!
	end
end

container.wait
```

If the health check does not complete within the specified timeout, the child process is killed:

```
 3.01s     warn: Async::Container::Forked [oid=0x1340] [ec=0x1348] [pid=27100] [2025-02-20 13:24:55 +1300]
               | Child failed health check!
               | {
               |   "child": {
               |     "name": "Unnamed",
               |     "pid": 27101,
               |     "status": null
               |   },
               |   "age": 1.0612829999881797,
               |   "health_check_timeout": 1
               | }
```
