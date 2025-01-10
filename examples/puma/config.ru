# frozen_string_literal: true

run do |env|
	[200, {"content-type" => "text/plain"}, ["Hello World #{Time.now}"]]
end
