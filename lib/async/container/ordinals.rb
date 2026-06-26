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
			
			# Base class for ordinal allocators.
			class Allocator
				# Reserve a fixed pool of ordinals from this allocator.
				# @parameter count [Integer] The number of ordinals to reserve.
				# @returns [Fixed] The reserved ordinals as a fixed allocator.
				def reserve(count)
					ordinals = []
					
					count.times do
						ordinals << acquire
					end
					
					return Fixed.new(ordinals)
				rescue
					release(ordinals) unless ordinals.empty?
					raise
				end
			end
			
			# A sequential ordinal allocator with lowest-released ordinal reuse.
			class Sequential < Allocator
				def initialize(initial = 0)
					@next = initial
					@free = Set.new
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
				
				# Return ordinals to the allocator.
				# @parameter ordinals [Enumerable(Integer)] The ordinals to release.
				def release(ordinals)
					ordinals.each do |ordinal|
						@free.add(ordinal)
					end
				end
			end
			
			# An allocator backed by a fixed set of ordinals.
			class Fixed < Allocator
				include Enumerable
				
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
				
				# Allocate the lowest available ordinal from the fixed pool.
				def acquire
					unless @free.empty?
						ordinal = @free.min
						@free.delete(ordinal)
						return ordinal
					end
					
					raise Exhausted, "No ordinals available!"
				end
				
				# Return ordinals to the fixed pool.
				# @parameter ordinals [Enumerable(Integer)] The ordinals to release.
				def release(ordinals)
					ordinals.each do |ordinal|
						unless @ordinals.include?(ordinal)
							raise ArgumentError, "Cannot release ordinal #{ordinal.inspect} to #{self.class}!"
						end
						
						@free.add(ordinal)
					end
				end
			end
		end
	end
end
