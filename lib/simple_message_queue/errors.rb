module SimpleMessageQueue

  class ConfigurationError < StandardError
    def initialize
      message = "SimpleMessageQueue has not been configured. Create an initializer with a SimpleMessageQueue.configure block and set the access_key_id and secret_access_key."
      super(message)
    end
  end

  class NotImplementedError < StandardError
    def initialize(name)
      message = "You must define the process_message method for #{name}"
      super(message)
    end
  end

end
