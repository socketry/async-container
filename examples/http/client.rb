#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2024, by Samuel Williams.

require 'async'
require 'async/http/endpoint'
require 'async/http/client'

endpoint = Async::HTTP::Endpoint.parse("http://localhost:9292")

Async do
	client = Async::HTTP::Client.new(endpoint)
	
	response = client.get("/")
	puts response.read
ensure
	client&.close
end
