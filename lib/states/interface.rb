class BroadcastForwarderWireGuard
  class States
    class Interface < CyberarmEngine::GuiState
      def setup
        theme(BroadcastForwarderWireGuard::THEME)

        background 0xff_252525

        stack(width: 1.0, height: 1.0, border_thickness: 1, border_color: 0x88_ffffff, padding: 4) do
          stack(width: 1.0, height: 0.15) do
            title "<b>Broadcast Forwarder</b>", width: 1.0, text_align: :center, text_size: 32
          end

          stack(width: 1.0, height: 1.0 - 0.30) do
            flow(width: 1.0, height: 0.15, margin_left: 8) do
              @total_rx = para "Rx: #{format_size(1024)}", width: 0.5
              @total_tx = para "Tx: #{format_size(10240)}", width: 0.5
            end

            @log_container = stack(width: 1.0, height: 0.78, padding: 2, scroll: true, margin_top: 4, border_thickness: 1, border_color: 0x88_000000) do
              background 0xaa_222222
            end
          end

          stack(width: 1.0, height: 0.20) do
            flow(width: 1.0, height: 1.0) do
              stack(width: 0.648) do
                inscription "<b>LAN:</b> #{@options[:real_lan_interface]}"
                inscription "<b>VPN:</b> #{@options[:real_vpn_interface]}", margin_top: -4
              end

              button "<b>Shutdown</b>", width: 0.35, tip: "Stop forwarder and close" do
                @proto_proxy&.stop!
                window.close
              end
            end
          end
        end

        @proto_proxy = ProtoProxy.new(gui: self)
        @last_transfer_refreshed_at = 0
      end

      def update
        super

        if Gosu.milliseconds - @last_transfer_refreshed_at >= 100.0
          @last_transfer_refreshed_at = Gosu.milliseconds

          @total_rx.value = "Rx: #{format_size(@proto_proxy.total_rx)}"
          @total_tx.value = "Tx: #{format_size(@proto_proxy.total_tx)}"

          # Discard old messages
          while (@log_container.children.count > 25)
            @log_container.children.shift

            @log_container.root.gui_state.request_recalculate_for(@log_container)
          end
        end
      end

      def log(message)
        # _last_scroll_position_y = @log_container.scroll_position.y
        # @log_container.scroll_position.y = -@log_container.max_scroll_height
        # root.gui_state.request_recalculate_for(@log_container) if _last_scroll_position_y != -@log_container.max_scroll_height

        @log_container.append do
          para "<c=2a2>[ #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} ]</c><c=44a>></c> <c=ee0>#{message}</c>", text_size: 12, text_shadow_color: 0xff_ffffff, text_shadow_size: 0.25
        end
      end

      def format_size(bytes)
        case bytes
        when 0..1023 # Bytes
          "#{bytes} B"
        when 1024..1_048_575 # KiloBytes
          "#{format_size_number(bytes / 1024.0)} KB"
        when 1_048_576..1_073_741_999 # MegaBytes
          "#{format_size_number(bytes / 1_048_576.0)} MB"
        else # GigaBytes
          "#{format_size_number(bytes / 1_073_742_000.0)} GB"
        end
      end

      def format_size_number(i)
        format("%0.2f", i)
      end
    end
  end
end
