unless RUBY_ENGINE == "mruby"
  require "socket"
  require "json"
end

class BroadcastForwarderWireGuard
  def initialize(config_file: "config.json")
    @config_file = config_file
    @config = JSON.parse(File.read(config_file))

    @running = true
    @sockets = []

    setup_sockets
    monitor_broadcasts
  end

  def setup_sockets
    @config["service_ports"].each do |port|
      socket = UDPSocket.new

      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)

      socket.bind("", port)

      @sockets << socket
    end
  end

  def monitor_broadcasts
    while(@running)
      ready = IO.select(@sockets)
  
      next unless ready

      ready[0].each do |socket|
        forward_broadcast_to_interfaces(socket.recvfrom(4096), socket)
      end
    end
  end

  def forward_broadcast_to_interfaces(message, socket)
    local_ip_addresses = Socket.ip_address_list.map(&:ip_address)

    peers = []

    @config["repeat_to_interfaces"].each do |hash|
      split_interface = hash["interface"].split(".")
      split_interface.delete(split_interface.last)

      base_interface_address = split_interface.join(".")
      pp base_interface_address

      # Inclusive, hence the minus 1
      (hash["end"] - (hash["start"] - 1)).times do |i|
        peers << "#{base_interface_address}.#{hash['start'] + i}"
      end
    end

    # Remove self
    local_ip_addresses.each { |address| peers.delete(address) }

    data, addr = message

    peers.each do |peer|
      socket.send(data, 0, peer, addr[1])
    end

    puts "got message: #{data[0..32]}"
  end
end

BroadcastForwarderWireGuard.new