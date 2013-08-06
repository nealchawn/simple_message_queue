module SimpleMessageQueue

  class ConfigurationError < StandardError
    def initialize
      message = "SimpleMessageQueue has not been configured. Create an initializer with a SimpleMessageQueue.configure block and set the access_key_id, secret_access_key and environment variable."
      super(message)
    end
  end

  class NotImplementedError < StandardError
    def initialize(name)
      message = "You must define the process_message method for #{name}"
      super(message)
    end
  end

  class EnvironmentError < StandardError
    def initialize
      message = "You must define the environment in the SimpleMessageQueue.configure block. Without setting the environment the same queue will be used across environments causing unwanted results."
      super(message)
    end
  end

end
