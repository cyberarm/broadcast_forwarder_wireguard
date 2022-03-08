lan_address = ARGV[0]
raise "IPv4 lan address not provided" unless lan_address.to_s.split(".").size == 4

require "socket"

socket = UDPSocket.new
socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)

socket.bind(lan_address, 24298)

loop do
  socket.send("#{Time.now}-#{lan_address}", 0, "255.255.255.255", 24298)

  sleep 3
end
