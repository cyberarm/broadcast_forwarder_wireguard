class BroadcastForwarderWireGuard
	class ProtoRepeater
		attr_reader :total_rx, :total_tx

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
				while (@running)
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
			socket = UDPSocket.new
			socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
			socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
			socket.bind(@vpn_interface, packet[1][1])

			socket.send(packet[0], 0, @broadcast_interface, packet[1][1])
			@total_rx += packet[0].length
			@total_tx += packet[0].length
			@broadcasts_forwarded += 1

			log("Repeated broadcast to #{@broadcast_interface}:#{packet[1][1]} on #{@vpn_interface}")
		end

    def log(message)
      puts "\e[32m[ #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} ]\e[0m\e[34m>\e[0m \e[33m#{message}\e[0m"
      @gui&.log(message)
    end
	end
end
