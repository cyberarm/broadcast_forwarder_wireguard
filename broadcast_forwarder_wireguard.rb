unless RUBY_ENGINE == "mruby"
  require "socket"
  require "json"
end

begin
  require_relative "../cyberarm_engine/lib/cyberarm_engine"
rescue LoadError
  require "cyberarm_engine"
end

class BroadcastForwarderWireGuard
  ROOT_PATH = File.expand_path("..", __FILE__)
end

require_relative "lib/window"
require_relative "lib/theme"
require_relative "lib/proto_proxy"
require_relative "lib/states/main_menu"
require_relative "lib/states/interface"

BroadcastForwarderWireGuard::Window.new(width: 320, height: 240).show unless defined?(Ocra)
# pp BroadcastForwarderWireGuard::ProtoProxy.new
