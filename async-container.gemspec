
require_relative 'lib/async/container/version'

Gem::Specification.new do |spec|
	spec.name          = "async-container"
	spec.version       = Async::Container::VERSION
	spec.authors       = ["Samuel Williams"]
	spec.email         = ["samuel.williams@oriontransfer.co.nz"]
	spec.description   = <<-EOF
		Provides containers for servers which provide concurrency policies, e.g. threads, processes.
	EOF
	spec.summary       = "Async is an asynchronous I/O framework based on nio4r."
	spec.homepage      = "https://github.com/socketry/async-container"
	spec.license       = "MIT"

	spec.files         = `git ls-files`.split($/)
	spec.executables   = spec.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
	spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
	spec.require_paths = ["lib"]
	
	spec.required_ruby_version = "~> 2.0"
	
	spec.add_runtime_dependency "process-group"
	
	spec.add_runtime_dependency "async", "~> 1.0"
	spec.add_runtime_dependency "async-io", "~> 1.26"
	
	spec.add_development_dependency "async-rspec", "~> 1.1"
	
	spec.add_development_dependency "covered"
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "rspec", "~> 3.6"
	spec.add_development_dependency "bake-bundler"
end
