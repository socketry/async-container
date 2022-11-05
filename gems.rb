# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020, by Samuel Williams.

source 'https://rubygems.org'

# Specify your gem's dependencies in utopia.gemspec
gemspec

group :maintenance, optional: true do
	gem "bake-bundler"
	gem "bake-modernize"
	
	gem "utopia-project"
end
