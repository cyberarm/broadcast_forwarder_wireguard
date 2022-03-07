class BroadcastForwarderWireGuard
  class OriginMutatedUDPSocket
    def initialize(interface = nil)
      # @socket = Socket.new(:INET, :RAW, Socket::IPPROTO_RAW)
      @socket = Socket.new(:INET, :RAW, Socket::IPPROTO_UDP)
      @socket.setsockopt(Socket::IPPROTO_IP, Socket::IP_HDRINCL, 1)
    end

    def send(source_address, target_address, original_packet)
      @source_address = source_address
      @target_address = target_address
      @original_packet = original_packet

      @original_packet_body, @original_packet_addrinfo = original_packet

      pp mutant_body

      # @socket.send(mutant_body, 0, @target_address)
    end

    def close
      @socket&.close
    end

    def mutant_body
      ipv4_capsule_with_header(udp_packet_with_header(@original_packet_body))
    end

    def ipv4_capsule_with_header(raw_udp_packet)
      IP_PDU.new(
        version: 4,
        header_length: 5,
        tos: 0,
        total_length: 20 + raw_udp_packet.to_binary_s.length,
        ident: 4444, # TODO
        flags: 0,
        frag_offset: 0,
        ttl: 128,
        protocol: 17,
        src_addr: "192.168.195.2",
        dest_addr: "192.168.1.117",
        options: 0,
        payload: raw_udp_packet
      ).to_binary_s
    end

    def udp_packet_with_header(data)
      UDP_PDU.new(
        src_port: 20_000,
        dst_port: 20_000,
        len: data.length,
        checksum: 3333, # TODO
        payload: data
      )
    end
  end

  #####################################################################
  #             Copied from bindata gem's examples                    #
  #                                                                   #
  # https://github.com/dmendel/bindata/blob/master/examples/tcp_ip.rb #
  #####################################################################

  # Present IP addresses in a human readable way
  class IP_Addr < BinData::Primitive
    array :octets, type: :uint8, initial_length: 4

    def set(val)
      self.octets = val.split(/\./).collect(&:to_i)
    end

    def get
      self.octets.collect { |octet| "%d" % octet }.join(".")
    end
  end

  # UDP Protocol Data Unit
  class UDP_PDU < BinData::Record
    endian :big

    uint16 :src_port
    uint16 :dst_port
    uint16 :len
    uint16 :checksum
    rest   :payload
  end

  class IP_PDU < BinData::Record
    endian :big

    bit4   :version, asserted_value: 4
    bit4   :header_length
    uint8  :tos
    uint16 :total_length
    uint16 :ident
    bit3   :flags
    bit13  :frag_offset
    uint8  :ttl
    uint8  :protocol
    uint16 :checksum
    ip_addr :src_addr
    ip_addr :dest_addr
    string :options, read_length: :options_length_in_bytes
    buffer :payload, length: :payload_length_in_bytes do
      choice :payload, selection: :protocol do
        udp_pdu 17
        rest    :default
      end
    end

    def header_length_in_bytes
      header_length * 4
    end

    def options_length_in_bytes
      header_length_in_bytes - options.rel_offset
    end

    def payload_length_in_bytes
      total_length - header_length_in_bytes
    end
  end
end

socket = BroadcastForwarderWireGuard::OriginMutatedUDPSocket.new
socket.send("192.168.195.2", "192.168.1.117", "???")