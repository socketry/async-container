# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "set"

module Async
	module Container
		# Allocates stable ordinal values for container workers.
		module Ordinals
			# Raised when no ordinal can be allocated.
			class Exhausted < RuntimeError
			end
			
			# A sequential ordinal allocator with lowest-released ordinal reuse.
			class Sequential
				def initialize(initial = 0)
					@next = initial
					@free = Set.new
				end
				
				# Reserve a fixed pool of ordinals from this allocator.
				# @parameter count [Integer] The number of ordinals to reserve.
				# @returns [Fixed] The reserved ordinals as a fixed allocator.
				def reserve(count)
					first = @next
					@next += count
					
					return Fixed.new(first...@next)
				end
				
				# Allocate the next available ordinal.
				def acquire
					unless @free.empty?
						ordinal = @free.min
						@free.delete(ordinal)
						return ordinal
					end
					
					ordinal = @next
					@next += 1
					return ordinal
				end
				
				# Return an ordinal to the allocator.
				# @parameter ordinal [Integer] The ordinal to release.
				def release(ordinal)
					@free.add(ordinal)
				end
			end
			
			# An allocator backed by a fixed set of ordinals.
			class Fixed
				include Enumerable
				
				# Create a fixed pool from a contiguous range of ordinals.
				# @parameter initial [Integer] The first ordinal in the range.
				# @parameter count [Integer] The number of ordinals in the range.
				# @returns [Fixed] The fixed allocator for the range.
				def self.range(initial, count)
					self.new(initial...(initial + count))
				end
				
				def initialize(ordinals)
					@ordinals = ordinals.to_set.freeze
					@free = @ordinals.dup
				end
				
				# @attribute [Set(Integer)] The ordinals managed by this allocator.
				attr :ordinals
				
				# Enumerate the ordinals managed by this allocator.
				def each(&block)
					@ordinals.each(&block)
				end
				
				# Reserve a fixed pool of ordinals from this allocator.
				# @parameter count [Integer] The number of ordinals to reserve.
				# @returns [Fixed] The reserved ordinals as a fixed allocator.
				def reserve(count)
					if count > @free.size
						raise Exhausted, "No ordinals available!"
					end
					
					ordinals = @free.min(count)
					ordinals.each do |ordinal|
						@free.delete(ordinal)
					end
					
					return Fixed.new(ordinals)
				end
				
				# Allocate the lowest available ordinal from the fixed pool.
				def acquire
					unless @free.empty?
						ordinal = @free.min
						@free.delete(ordinal)
						return ordinal
					end
					
					raise Exhausted, "No ordinals available!"
				end
				
				# Return an ordinal to the fixed pool.
				# @parameter ordinal [Integer] The ordinal to release.
				def release(ordinal)
					unless @ordinals.include?(ordinal)
						raise ArgumentError, "Cannot release ordinal #{ordinal.inspect} to #{self.class}!"
					end
					
					@free.add(ordinal)
				end
			end
		end
	end
end
