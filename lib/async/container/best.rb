# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require_relative 'forked'
require_relative 'threaded'
require_relative 'hybrid'

module Async
	module Container
		# Whether the underlying process supports fork.
		# @returns [Boolean]
		def self.fork?
			::Process.respond_to?(:fork) && ::Process.respond_to?(:setpgid)
		end
		
		# Determins the best container class based on the underlying Ruby implementation.
		# Some platforms, including JRuby, don't support fork. Applications which just want a reasonable default can use this method.
		# @returns [Class]
		def self.best_container_class
			if fork?
				return Forked
			else
				return Threaded
			end
		end
		
		# Create an instance of the best container class.
		# @returns [Generic] Typically an instance of either {Forked} or {Threaded} containers.
		def self.new(*arguments, **options)
			best_container_class.new(*arguments, **options)
		end
	end
end
