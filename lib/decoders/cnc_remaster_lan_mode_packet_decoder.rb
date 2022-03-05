#################################################
# In research phase.
#
# CnC Remastered Collection LAN Lobby Broadcast Packet Description (Red Alert)
#
# 0x00 - The first 4-bytes change for every packet, but each packet has at least one change; checksum?
# 0x04 - The next 4-bytes are fixed across packets, suggesting its a protocol or game identifier
# 0x08 - The next byte apprears to be a flag of some kind
# 0x09 - The next byte might be identifying the packet type
# 0x10 - The next 2-bytes might be the packet ID/counter of some sort
# 0x12 - ???

require "stringio"
require "digest" # crc32 requires gem: digest-crc

class CNCRemasteredCollectionLANModePacketDecoder
  PACKET_TYPES = {
    lobby_idle_join:    28,  # UNKNOWN
    lobby_hosting:      122, # UNKNOWN
    lobby_initial_host: 204, # UNKNOWN
  }

  def initialize(raw:)
    @buffer = StringIO.new(raw)

    decode
  end

  def decode
    @checksum = to_hex(read_u32)
    @protocol_identifier = to_hex(read_u32)
    unknown_flag = read_u8
    unknown_packet_type = read_u8
    unknown_packet_id = read_u16
    unknown_0 = read_u32

    puts "CHECKSUM:               #{@checksum}"
    puts "PROTOCOL ID:            #{@protocol_identifier}"
    puts "!UNKNOWN: FLAG(s)?:     #{unknown_flag}"
    puts "!UNKNOWN: PACKET TYPE?: #{unknown_packet_type}"
    puts "!UNKNOWN: PACKET ID?:   #{unknown_packet_id}"
    puts "!UNKNOWN: 0:            #{unknown_0}"

    completely_unknown_bytes = @buffer.length - @buffer.pos

    completely_unknown_data = @buffer.read

    puts "!UNKNOWN: ---:          #{completely_unknown_data.bytes.pack("c*").unpack1("H*")}"

    puts "Bytes remaining after known bytes: #{completely_unknown_bytes}"
  end

  #######################
  # Assuming Big Endian #
  #######################

  def read_i8
    @buffer.read(1).unpack1("c")
  end

  def read_u8
    @buffer.read(1).unpack1("C")
  end

  def read_i16
    @buffer.read(2).unpack1("s>")
  end

  def read_u16
    @buffer.read(2).unpack1("S>")
  end

  def read_i32
    @buffer.read(4).unpack1("l>")
  end

  def read_u32
    @buffer.read(4).unpack1("L>")
  end

  def read_string
    buffer = ""

    length = @buffer.readbyte

    length.times do
      buffer << @buffer.readbyte
    end

    buffer.strip
  end

  def crc32(bytes)
    Digest::CRC32.hexdigest(bytes)
  end

  def to_hex(u32)
    u32.to_s(16).rjust(8, "0")
  end
end

CNCRemasteredCollectionLANModePacketDecoder.new(raw: File.binread("../../Downloads/cnc_lan_broadcast_packets/idle_lobby_join.bin"))
CNCRemasteredCollectionLANModePacketDecoder.new(raw: File.binread("../../Downloads/cnc_lan_broadcast_packets/idle_lobby_join_2.bin"))
CNCRemasteredCollectionLANModePacketDecoder.new(raw: File.binread("../../Downloads/cnc_lan_broadcast_packets/initial_hosting_lobby.bin"))
CNCRemasteredCollectionLANModePacketDecoder.new(raw: File.binread("../../Downloads/cnc_lan_broadcast_packets/initial_hosting_lobby_2.bin"))