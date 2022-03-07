class BroadcastForwarderWireGuard
  class OriginMutatedUDPSocket
    def initialize(source_address, target_address, original_packet)
      @source_address = source_address
      @target_address = target_address
      @original_packet = original_packet

      @original_packet_body, @original_packet_addrinfo = original_packet

      # @socket = Socket.new(:INET, :RAW, Socket::IPPROTO_RAW)
      @socket = Socket.new(:INET, :RAW, Socket::IPPROTO_UDP)
      @socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_HDRINCL, 1)

      @socket.send(mutant_body, 0 , @target_address)
    end

    def close
      @socket&.close
    end

    def mutant_body
      ipv4_header + udp_header + @original_packet_body
    end

    def ipv4_header
    end

    def udp_header
    end
  end
end

BroadcastForwarderWireGuard::OriginMutatedUDPSocket.new("192.168.195.2", "192.168.1.117", "???")