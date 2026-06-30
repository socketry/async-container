# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2025, by Samuel Williams.

# This sets up graceful handling of SIGINT and SIGTERM.
require "async/signals/graceful"

require_relative "container/controller"
