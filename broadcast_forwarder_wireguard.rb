unless RUBY_ENGINE == "mruby"
  require "socket"
  require "json"
end

require "cyberarm_engine"
require "optparse"

class BroadcastForwarderWireGuard
  ROOT_PATH = File.expand_path("..", __FILE__)
end

require_relative "lib/window"
require_relative "lib/theme"
# require_relative "lib/proto_proxy"
require_relative "lib/proto_repeater"
require_relative "lib/states/main_menu"
require_relative "lib/states/interface"

options = {}

OptionParser.new do |parser|
  parser.banner = "Usage: broadcast_forwarder_wireguard.rb [options]"

  parser.on("--lan=ADDRESS", "IPv4 address for lan interface") do |n|
    options[:lan_interface] = n
  end

  parser.on("--vpn=ADDRESS", "IPv4 address for vpn interface") do |n|
    options[:vpn_interface] = n
  end
end.parse!

if options.empty?
  BroadcastForwarderWireGuard::Window.new(width: 320, height: 240).show unless defined?(Ocra)
else
  BroadcastForwarderWireGuard::ProtoRepeater.new(
    lan_interface: options[:lan_interface],
    vpn_interface: options[:vpn_interface],
  )
end
