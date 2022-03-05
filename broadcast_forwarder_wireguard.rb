unless RUBY_ENGINE == "mruby"
  require "socket"
  require "json"
end

class BroadcastForwarderWireGuard
  ROOT_PATH = File.expand_path("..", __FILE__)

  def initialize(config_file: "#{ROOT_PATH}/config/config.json")
    log "Loading config: #{config_file}..."
    @config_file = config_file
    @config = JSON.parse(File.read(config_file))

    @running = true
    @sockets = []

    @repeater_sockets = [] # Listens for remote traffic and resends on real interfaces

    @forwarded_broadcasts = 0
    @last_notified_forwarded_broadcasts = @forwarded_broadcasts
    @last_notified_forwarded_broadcasts_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @log_forwarded_broadcasts_after = 10.0

    at_exit do
      log "Shutting down... Forwarded a total of #{@forwarded_broadcasts} broadcasts."
      @sockets.each do |socket|
        socket&.close
      end
    end

    log "Will deliver remote broadcasts to real interface: #{@config["local_real_interface"]}, sent to vpn interface: #{@config["local_vpn_interface"]}"

    log "Setting up sockets..."
    setup_sockets
    log "Listening for broadcasts..."
    monitor_broadcasts
  end

  def setup_sockets
    @config["service_ports"].each do |port|
      log "   Subscribing to broadcasts on port #{port}..."
      socket = UDPSocket.new

      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)

      socket.bind("", port)

      @sockets << socket

      # Remote to local capture socket; Capture inbound broadcasts sent from VPN peers
      socket = UDPSocket.new
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)

      socket.bind(@config["local_vpn_interface"], port)

      @repeater_sockets << socket
      @sockets << socket
    end
  end

  def monitor_broadcasts
    while @running
      ready = IO.select(@sockets)

      next unless ready

      ready[0].each do |socket|
        if @repeater_sockets.any?(socket)
          local_broadcast_to_interface(socket.recvfrom(4096), socket)
        else
          forward_broadcast_to_interfaces(socket.recvfrom(4096), socket)
        end
      end
    end
  end

  def local_broadcast_to_interface(message, socket)
    data, addr = message

    log "Repeating remote message from #{addr[2]}:#{addr[1]} of length: #{data.length}"

    # Remote to local delivery socket; tries to deliver remote broadcast to local game client
    socket_exist = @sock
    @sock ||= UDPSocket.new
    @sock.bind("local_real_interface", 0) unless socket_exist

    @sock.send(data, 0, @config["local_real_interface"], addr[1])
  end

  def forward_broadcast_to_interfaces(message, socket)
    local_ip_addresses = Socket.ip_address_list.map(&:ip_address)

    peers = []

    @config["repeat_to_interfaces"].each do |hash|
      split_interface = hash["interface"].split(".")
      split_interface.delete(split_interface.last)

      base_interface_address = split_interface.join(".")

      # Inclusive, hence the minus 1
      (hash["end"] - (hash["start"] - 1)).times do |i|
        peers << "#{base_interface_address}.#{hash['start'] + i}"
      end
    end

    # Remove self
    my_addresses = []
    local_ip_addresses.each { |address| my_addresses << peers.delete(address) }

    data, addr = message

    peers.each do |peer|
      socket.send(data, 0, peer, addr[1])
    end

    # pp my_addresses

    @forwarded_broadcasts += 1

    if Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_notified_forwarded_broadcasts_at >= @log_forwarded_broadcasts_after
      log "Forwarded #{@forwarded_broadcasts - @last_notified_forwarded_broadcasts} broadcasts to #{peers.count} peers across #{@config["repeat_to_interfaces"].count} interfaces..."

      @last_notified_forwarded_broadcasts = @forwarded_broadcasts
      @last_notified_forwarded_broadcasts_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end

  def log(message)
    puts "\e[32m[ #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} ]\e[0m\e[34m>\e[0m \e[33m#{message}\e[0m"
  end
end

BroadcastForwarderWireGuard.new unless defined?(Ocra)
