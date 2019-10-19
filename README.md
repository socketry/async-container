# Async::Container

Provides containers which implement concurrency policy for high-level servers (and potentially clients).

[![Actions Status](https://github.com/socketry/async-container/workflows/Tests/badge.svg)](https://github.com/socketry/async-container/actions?workflow=Tests)
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

```ruby
container = Async::Container::Threaded.new

container.run(count: 8)
	# 8 reactors will be spawned, in separate threads.
	Server.new.run(...)
end

container = Async::Container::Forked.new

container.run(count: 8) do
	# 8 reactors will be spawned, in separate forked processes.
	Server.new.run(...)
end
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
