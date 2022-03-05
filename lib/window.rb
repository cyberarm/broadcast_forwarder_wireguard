class BroadcastForwarderWireGuard
  class Window < CyberarmEngine::Window
    def setup
      self.caption = "Broadcast Forwarder"
      self.show_cursor = true
      self.update_interval = 1000.0 / 10

      push_state(States::MainMenu)
    end

    def lose_focus
      self.update_interval = 1000.0 / 2
    end

    def gain_focus
      self.update_interval = 1000.0 / 10
    end
  end
end
