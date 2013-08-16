module SimpleMessageQueue
  class Configuration
    attr_accessor :access_key_id, :secret_access_key, :logger, :idle_timeout, :wait_time_seconds, :environment, :sns_notifications, :sns_notification_prefix

    def initialize
      @access_key_id = nil
      @secret_access_key = nil
      @logger = nil
      @idle_timeout = 10
      @wait_time_seconds = 20
      @environment = nil
      @sns_notifications = false
      @sns_notification_prefix = nil
    end
  end
end
