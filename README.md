# Async::Container

Provides containers which implement concurrency policy for high-level servers (and potentially clients).

[![Actions Status](https://github.com/socketry/async-container/workflows/Development/badge.svg)](https://github.com/socketry/async-container/actions?workflow=Development)
[![Code Climate](https://codeclimate.com/github/socketry/async-container.svg)](https://codeclimate.com/github/socketry/async-container)
[![Coverage Status](https://coveralls.io/repos/socketry/async-container/badge.svg)](https://coveralls.io/r/socketry/async-container)

## Installation

Add this line to your application's Gemfile:

```ruby
gem "async-container"
```

And then execute:

	$ bundle

Or install it yourself as:

	$ gem install async

## Usage

### Container

A container represents a set of child processes (or threads) which are doing work for you.

```ruby
require 'async/container'

Async.logger.debug!

container = Async::Container.new

container.async do |task|
	task.logger.debug "Sleeping..."
	task.sleep(1)
	task.logger.debug "Waking up!"
end

Async.logger.debug "Waiting for container..."
container.wait
Async.logger.debug "Finished."
```

### Controller

The controller provides the life-cycle management for one or more containers of processes. It provides behaviour like starting, restarting, reloading and stopping. You can see some [example implementations in Falcon](https://github.com/socketry/falcon/blob/master/lib/falcon/controller/). If the process running the controller receives `SIGHUP` it will recreate the container gracefully.

```ruby
require 'async/container'

Async.logger.debug!

class Controller < Async::Container::Controller
	def setup(container)
		container.async do |task|
			while true
				Async.logger.debug("Sleeping...")
				task.sleep(1)
			end
		end
	end
end

controller = Controller.new

controller.run

# If you send SIGHUP to this process, it will recreate the container.
```

### Signal Handling

`SIGINT` is the interrupt signal. The terminal sends it to the foreground process when the user presses **ctrl-c**. The default behavior is to terminate the process, but it can be caught or ignored. The intention is to provide a mechanism for an orderly, graceful shutdown.

`SIGQUIT` is the dump core signal. The terminal sends it to the foreground process when the user presses **ctrl-\**. The default behavior is to terminate the process and dump core, but it can be caught or ignored. The intention is to provide a mechanism for the user to abort the process. You can look at `SIGINT` as "user-initiated happy termination" and `SIGQUIT` as "user-initiated unhappy termination."

`SIGTERM` is the termination signal. The default behavior is to terminate the process, but it also can be caught or ignored. The intention is to kill the process, gracefully or not, but to first allow it a chance to cleanup.

`SIGKILL` is the kill signal. The only behavior is to kill the process, immediately. As the process cannot catch the signal, it cannot cleanup, and thus this is a signal of last resort.

`SIGSTOP` is the pause signal. The only behavior is to pause the process; the signal cannot be caught or ignored. The shell uses pausing (and its counterpart, resuming via `SIGCONT`) to implement job control.

### Integration

#### systemd

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

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

Released under the MIT license.

Copyright, 2017, by [Samuel G. D. Williams](http://www.codeotaku.com/samuel-williams).

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
