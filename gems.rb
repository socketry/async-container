# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2024, by Samuel Williams.

source 'https://rubygems.org'

# Specify your gem's dependencies in utopia.gemspec
gemspec

group :maintenance, optional: true do
	gem "bake-bundler"
	gem "bake-modernize"
	
	gem "utopia-project"
end

group :test do
	gem "sus"
	gem "covered"
	
	gem "bake-test"
	gem "bake-test-external"
end
