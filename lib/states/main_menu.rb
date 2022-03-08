class BroadcastForwarderWireGuard
  class States
    class MainMenu < CyberarmEngine::GuiState
      def setup
        theme(BroadcastForwarderWireGuard::THEME)

        background 0xff_252525

        stack(width: 1.0, height: 1.0, border_thickness: 1, border_color: 0x88_ffffff, padding: 4) do
          stack(width: 1.0, height: 0.35) do
            title "<b>Broadcast Forwarder</b>", width: 1.0, text_align: :center, text_size: 32
            inscription "Captures packets sent to certain configured local ports and forwards them over the VPN."
          end

          stack(width: 1.0, height: 0.25) do
            flow(width: 1.0, height: 1.0) do
              para "<b>LAN Interface</b>", width: 0.4, margin_top: 6, tip: "Interface of your real network/network with router"
              @lan_interface = list_box items: [""], width: 0.47, tip: "Select LAN interface"
              button "R", width: 0.12, tip: "Refresh interface list" do
                refresh_ip_address_list
              end
            end
          end

          stack(width: 1.0, height: 0.25) do
            flow(width: 1.0, height: 1.0) do
              para "<b>VPN Interface</b>", width: 0.4, margin_top: 6, tip: "Interface of the VPN network"
              @vpn_interface = list_box items: [""], width: 0.47, tip: "Select VPN interface"
              button "R", width: 0.12, tip: "Refresh interface list" do
                refresh_ip_address_list
              end
            end
          end

          stack(width: 1.0, height: 0.20) do
            flow(width: 1.0, height: 1.0) do
              button "<b>Close</b>", width: 0.25, tip: "Close application" do
                window.close
              end

              stack(width: 0.49)

              @start_btn = button "<b>Start</b>", width: 0.25, tip: "Start forwarder (may get a firewall authorization)", enabled: false do
                push_state(States::Interface, real_lan_interface: @lan_interface.value, real_vpn_interface: @vpn_interface.value)
              end
            end
          end
        end

        @lan_interface.subscribe(:changed) do
          @start_btn.enabled = interfaces_valid?
        end

        @vpn_interface.subscribe(:changed) do
          @start_btn.enabled = interfaces_valid?
        end

        @config = JSON.parse(File.read("#{ROOT_PATH}/config/config.json"))
        refresh_ip_address_list(true)
      end

      def refresh_ip_address_list(initial = false)
        @local_ip_addresses = Socket.ip_address_list.select(&:ipv4?).map(&:ip_address).select { |ip| ip != "127.0.0.1" }
        @local_ip_addresses = [""] if @local_ip_addresses.empty?

        @lan_interface.items = @local_ip_addresses.clone
        @vpn_interface.items = @local_ip_addresses.clone

        return unless initial

        return unless @local_ip_addresses.size > 1

        # Assume 192.168.0 and 192.168.1 are LAN interfaces
        @lan_interface.value = @local_ip_addresses.find { |ip| ip.start_with?("192.168.0.") || ip.start_with?("192.168.1.") }
        @vpn_interface.value = @local_ip_addresses.find { |ip| !ip.start_with?("192.168.0.") && !ip.start_with?("192.168.1.") }
      end

      def interfaces_valid?
        @lan_interface.value != @vpn_interface.value &&
          @local_ip_addresses.include?(@lan_interface.value) &&
          @local_ip_addresses.include?(@vpn_interface.value)
      end
    end
  end
end
