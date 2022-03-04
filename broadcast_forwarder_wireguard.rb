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

    log "Setting up sockets..."
    setup_sockets
    log "Listening for broadcasts on ports: #{@config["service_ports"].join(", ")}"
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
    while @running
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
