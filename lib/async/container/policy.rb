# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Async
	module Container
		# A policy for managing container behavior and responding to child process lifecycle events.
		class Policy
			# Called when a child is spawned.
			# @parameter container [Generic] The container.
			# @parameter child [Child] The child process.
			# @parameter name [String] The name of the child.
			# @parameter key [Symbol] An optional key for the child.
			# @parameter options [Hash] Additional options for future extensibility.
			def child_spawn(container, child, name:, key:, **options)
			end
			
			# Called when a child exits.
			# @parameter container [Generic] The container.
			# @parameter child [Child] The child process.
			# @parameter status [Process::Status] The exit status.
			# @parameter name [String] The name of the child.
			# @parameter key [Symbol] An optional key for the child.
			# @parameter options [Hash] Additional options for future extensibility.
			def child_exit(container, child, status, name:, key:, **options)
			end
			
			# Called when a health check fails.
			# Subclasses can override to implement custom behavior (e.g., alerting before killing).
			# @parameter container [Generic] The container.
			# @parameter child [Child] The child process.
			# @parameter age [Numeric] How long the child has been running.
			# @parameter timeout [Numeric] The health check timeout that was exceeded.
			# @parameter options [Hash] Additional options for future extensibility.
			def health_check_failed(container, child, age:, timeout:, **options)
				Console.warn(self, "Health check failed!", child: child, age: age, timeout: timeout)
				child.kill!
			end
			
			# Called when startup fails (child doesn't become ready in time).
			# Subclasses can override to implement custom behavior (e.g., alerting before killing).
			# @parameter container [Generic] The container.
			# @parameter child [Child] The child process.
			# @parameter age [Numeric] How long the child has been running.
			# @parameter timeout [Numeric] The startup timeout that was exceeded.
			# @parameter options [Hash] Additional options for future extensibility.
			def startup_failed(container, child, age:, timeout:, **options)
				Console.warn(self, "Startup failed!", child: child, age: age, timeout: timeout)
				child.kill!
			end
			
			# Helper method to check if a status indicates a segfault.
			# @parameter status [Process::Status] The exit status.
			# @returns [Boolean] Whether the process was terminated by SIGSEGV.
			def segfault?(status)
				status&.termsig == Signal.list["SEGV"]
			end
			
			# Helper method to check if a status indicates an abort.
			# @parameter status [Process::Status] The exit status.
			# @returns [Boolean] Whether the process was terminated by SIGABRT.
			def abort?(status)
				status&.termsig == Signal.list["ABRT"]
			end
			
			# Helper method to check if a status indicates the process was killed.
			# @parameter status [Process::Status] The exit status.
			# @returns [Boolean] Whether the process was terminated by SIGKILL.
			def killed?(status)
				status&.termsig == Signal.list["KILL"]
			end
			
			# Helper method to check if a status indicates success.
			# @parameter status [Process::Status] The exit status.
			# @returns [Boolean] Whether the process exited successfully.
			def success?(status)
				status&.success?
			end
			
			# Helper method to get the signal that terminated the process.
			# @parameter status [Process::Status] The exit status.
			# @returns [Integer, nil] The signal number, or nil if not terminated by signal.
			def signal(status)
				status&.termsig
			end
			
			# Helper method to get the exit code.
			# @parameter status [Process::Status] The exit status.
			# @returns [Integer, nil] The exit code, or nil if terminated by signal.
			def exit_code(status)
				status&.exitstatus
			end
			
			# The default policy instance.
			DEFAULT = self.new.freeze
		end
	end
end
