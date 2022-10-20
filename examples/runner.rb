# frozen_string_literal: true

# Run this file with `async-container`
# > async-container --count 5 --forked --restart examples/runner.rb

require 'securerandom'

class Worker
  include Console

  attr_reader :container, :instance, :options, :id

  def initialize(container, instance, options)
    @container = container
    @instance = instance
    @options = options
    @id = SecureRandom.hex(5)
  end

  def run
    logger.info "[#{id}] working..."

    loop do
      sleep 1
      if rand < 0.2
        raise "random error"
      end
    end
  end

  def stop
    logger.info "[#{id}] cleaning up..."
  end
end

before do |_container, options|
  Console.logger.info(self, "=> Preparing workers...", options)
end

run do |instance, container, options|
  worker = Worker.new(instance, container, options)
  worker.run
ensure
  worker.stop
end
