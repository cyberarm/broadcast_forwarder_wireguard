require "socket"

socket = UDPSocket.new
socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)

socket.bind("", 24298)

loop do
  socket.send("#{Time.now}", 0, "192.168.195.29", 24298)

  sleep 3
end
