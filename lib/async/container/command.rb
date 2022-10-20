# frozen_string_literal: true

# Copyright, 2022, by Samuel G. D. Williams. <http://www.codeotaku.com>
# Copyright, 2022, by Anton Sozontov.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'pry'
require 'samovar'

module Async
  module Container
    class Command < Samovar::Command
      self.description = "Scalable multi-thread multi-process container"

      # The command line options.
      # @attribute [Samovar::Options]
      options do
        option '--verbose | --quiet', "Verbosity of output for debugging.", key: :logging
        option '-h/--help', "Print out help information."
        option '-v/--version', "Print out the application version."
        option '--restart', "Restart containers if they fail"

        option '--forked | --threaded | --hybrid', "Select a specific parallelism model.", key: :container, default: :forked

        option '-n/--count <count>', "Number of instances to start.", default: Async::Container.processor_count, type: Integer

        option '--forks <count>', "Number of forks (hybrid only).", type: Integer
        option '--threads <count>', "Number of threads (hybrid only).", type: Integer
      end

      one :file

      # Whether verbose logging is enabled.
      # @returns [Boolean]
      def verbose?
        @options[:logging] == :verbose
      end

      # Whether quiet logging was enabled.
      # @returns [Boolean]
      def quiet?
        @options[:logging] == :quiet
      end

      # Prepare the environment and invoke the sub-command.
      def call
        if @options[:version]
          puts "#{self.name} v#{Async::Container::VERSION}"
        elsif @options[:help]
          self.print_usage
        else
          run
        end
      end

      # The container class to use.
      def container_class
        case @options[:container]
        when :threaded
          return Async::Container::Threaded
        when :forked
          return Async::Container::Forked
        when :hybrid
          return Async::Container::Hybrid
        end
      end

      def container_options
        if @options[:container] == :hybrid
          options.slice(:count, :forks, :threads, :name, :restart, :key)
        else
          options.slice(:count, :name, :restart, :key)
        end
      end

      private

      class DSL # :private:
        attr_reader :block, :options

        def initialize(file, **options)
          path = File.realpath(file)
          @options = options
          instance_eval File.read(path), path
        end

        def before(container=nil, options=nil, &block)
          if block_given?
            @before_block = block
          else
            @before_block&.call(container, options)
          end
        end

        def run(&block)
          @block = block
        end

        def intro
          type = options[:container].to_s.capitalize
          Console.logger.info "=> Starting #{type} async containers"
        end

        def self.to_s
          "Runner"
        end
      end

      class Controller < Async::Container::Controller # :private:
        def self.run_file(command)
          dsl = DSL.new(command.file, **command.options)

          define_method :create_container do
            command.container_class.new
          end

          define_method :setup do |container|
            dsl.before container, dsl.options
            dsl.intro

            container.run(name: command.file, **command.container_options) do |instance|
              instance.ready!
              dsl.block.call instance, container, dsl.options
            end
          end

          new.run
        end
      end

      def run
        Controller.run_file(self)
      end
    end
  end
end
