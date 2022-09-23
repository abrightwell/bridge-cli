require "../src/cb"
require "./factory"
require "spec"
require "spectator"
require "spectator/should"

include CB

Colorize.enabled = false
TEST_TOKEN = CB::Token.new("localhost", "token", Time.local.to_unix + 1.hour.seconds, "userid", "user name")

def expect_cb_error(message, file = __FILE__, line = __LINE__)
  expect_raises(CB::Program::Error, message, file: file, line: line) { yield }
end
