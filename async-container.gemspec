# frozen_string_literal: true

require_relative "lib/async/container/version"

Gem::Specification.new do |spec|
	spec.name = "async-container"
	spec.version = Async::Container::VERSION
	
	spec.summary = "Abstract container-based parallelism using threads and processes where appropriate."
	spec.authors = ["Samuel Williams", "Olle Jonsson", "Anton Sozontov", "Juan Antonio Martín Lucas", "Yuji Yaginuma"]
	spec.license = "MIT"
	
	spec.cert_chain  = ['release.cert']
	spec.signing_key = File.expand_path('~/.gem/release.pem')
	
	spec.homepage = "https://github.com/socketry/async-container"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/async-container/",
		"source_code_uri" => "https://github.com/socketry/async-container.git",
	}
	
	spec.files = Dir.glob(['{lib}/**/*', '*.md'], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.1"
	
	spec.add_dependency "async", "~> 2.10"
end
