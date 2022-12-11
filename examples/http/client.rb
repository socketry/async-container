
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
