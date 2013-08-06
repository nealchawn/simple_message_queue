module SimpleMessageQueue
  class Configuration
    attr_accessor :access_key_id, :secret_access_key, :logger, :idle_timeout, :wait_time_seconds, :environment

    def initialize
      @access_key_id = nil
      @secret_access_key = nil
      @logger = nil
      @idle_timeout = 10
      @wait_time_seconds = 20
      @environment = nil
    end
  end
end
