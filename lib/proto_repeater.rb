class BroadcastForwarderWireGuard
  class ProtoRepeater
    attr_reader :total_rx, :total_tx, :broadcasts_forwarded

    def initialize(lan_interface:, vpn_interface:, config_file: "#{ROOT_PATH}/config/config.json", gui: nil)
      @lan_interface = lan_interface
      @vpn_interface = vpn_interface

      log "Loading config: #{config_file}..."
      @config = JSON.parse(File.read(config_file))
      @gui = gui

      @running = true
      @sockets = []

      @broadcast_interface = "255.255.255.255"

      @broadcasts_forwarded = 0
      @total_rx = 0
      @total_tx = 0

      @recent_packets = []
      @ring_index = 0
      @ring_size = 50

      at_exit do
        log "Shutting down... Forwarded a total of #{@forwarded_broadcasts} broadcasts."
        @sockets.each do |socket|
          socket&.close
        end
      end

      log "Will deliver local broadcasts to vpn interface: #{@vpn_interface}, sent to lan interface: #{@lan_interface}"

      log "Setting up sockets..."
      setup_sockets
      log "Listening for broadcasts..."
      listen
    end

    def setup_sockets
      @config["service_ports"].each do |port|
        log "Listening for broadcasts on port #{port}..."

        socket = UDPSocket.new
        socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)

        socket.bind(@lan_interface, port)

        @sockets << socket
      end
    end

    def listen
      @runner = Thread.new do
        while @running
          ready = IO.select(@sockets)

          ready[0].each do |socket|
            send_broadcast(socket.recvfrom(4096))
          end
        end
      end

      @runner.join unless @gui
    end

    def stop!
      @running = false
      @runner&.exit
    end

    def send_broadcast(packet)
      if packet[1][2] != @lan_interface
        log "Mirror prevented for #{packet[1][2]}:#{packet[1][1]}"
        return
      end

      # Prevent lan-to-lan repeat, maybe? Not needed?
      if @recent_packets.include?(checksum_packet(packet))
        log "SKIPPING REPEAT"
        return
      end

      save_recent_packet(packet)

      socket = UDPSocket.new
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
      socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
      socket.bind(@vpn_interface, packet[1][1])

      socket.send(packet[0], 0, @broadcast_interface, packet[1][1])
      @total_rx += packet[0].length
      @total_tx += packet[0].length
      @broadcasts_forwarded += 1

      log("Repeated broadcast from #{packet[1][2]}:#{packet[1][1]} to #{@vpn_interface}:#{packet[1][1]}")
    end

    # "checksum"
    def checksum_packet(packet)
      msg, addr = packet

      msg
    end

    def save_recent_packet(packet)
      cksum = checksum_packet(packet)

      @recent_packets[@ring_index] = cksum
      @ring_index += 1
      @ring_index = 0 if @ring_index >= @ring_size
    end

    def log(message)
      puts "\e[32m[ #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} ]\e[0m\e[34m>\e[0m \e[33m#{message}\e[0m"

      return unless @gui

      @gui.log(message)

      @gui.log_container.scroll_position.y = -@gui.log_container.max_scroll_height
      @gui.request_recalculate_for(@gui.log_container)
    end
  end
end
