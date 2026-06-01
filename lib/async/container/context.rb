# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Udi Oron.

module Async
	module Container
		# A single level of a worker's execution context.
		# @attribute kind [Symbol] Either `:process` or `:thread`.
		# @attribute num [Integer] The container-scoped ordinal of the worker at this level.
		# @attribute name [String | Nil] The name the container was given for this worker.
		Frame = Data.define(:kind, :num, :name)
		
		# Mixed into each container's `Child::Instance` to expose its place in the worker
		# hierarchy. The frame stack is built from the object graph (this instance plus its
		# parent chain), so worker code that holds the instance - e.g. an async-service
		# `prepare!(instance)` hook - can read its durable worker number with no process or
		# thread globals.
		module Context
			# The instance of the worker this one is nested inside, or `nil` at the top level.
			# A {Hybrid} thread's parent is its fork; a plain {Forked}/{Threaded} worker has none.
			attr_accessor :parent
			
			# The execution context as a {Frame} stack, outermost level first.
			# @returns [Array(Frame)] e.g. `[process, thread]` for a Hybrid thread worker.
			def context
				(parent ? parent.context : []) + [Frame.new(kind: kind, num: num, name: name)]
			end
		end
	end
end
