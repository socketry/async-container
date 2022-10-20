
require_relative "lib/async/container/version"

Gem::Specification.new do |spec|
	spec.name = "async-container"
	spec.version = Async::Container::VERSION
	
	spec.summary = "Abstract container-based parallelism using threads and processes where appropriate."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.homepage = "https://github.com/socketry/async-container"
	
	spec.files = Dir.glob('{lib}/**/*', File::FNM_DOTMATCH, base: __dir__)
	spec.bindir        = "exe"
	spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }

	spec.required_ruby_version = ">= 2.5"
	
	spec.add_dependency "async"
	spec.add_dependency "async-io"
	spec.add_dependency "samovar", "~> 2.1"

	spec.add_development_dependency "async-rspec", "~> 1.1"
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "covered"
	spec.add_development_dependency "rspec", "~> 3.6"
end
