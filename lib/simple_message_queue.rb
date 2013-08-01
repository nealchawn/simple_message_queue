require 'simple_message_queue/configuration'
require 'simple_message_queue/core_ext/string'
require 'simple_message_queue/errors'
require 'aws'

module SimpleMessageQueue
  class << self
    # Class Methods only available to SimpleMessageQueue
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration)
    end

  end

  def sqs
    raise SimpleMessageQueue::ConfigurationError unless SimpleMessageQueue.configuration
    @@sqs ||= AWS::SQS.new(:access_key_id => SimpleMessageQueue.configuration.access_key_id, :secret_access_key => SimpleMessageQueue.configuration.secret_access_key)
  end

  def queue_name
    name.underscore.gsub('/', '_')
  end

  def queue
    @queue ||= sqs.queues.create(queue_name)
  end

  def count
    queue.approximate_number_of_messages
  end

   def delete_queue
    queue.delete
  end

  def exists?
    # Although there is a queue.exists? method, that is only relevant if you already have the queue stored in a variable and then delete it
    # Trying to look it up by name will either return the queue object or throw an error, hence the rescue
    true if sqs.queues.named(queue_name)
  rescue
    false
  end

  def send(message)
    queue.send_message(message)
  end

  def logger
    if SimpleMessageQueue.configuration.logger
      @logger ||= SimpleMessageQueue.configuration.logger
    else
      @logger ||= Logger.new(STDOUT)
    end
  end

  def receive
    @count = 0
    logger.info "Receiving messages for #{queue_name} at #{DateTime.now}"
    queue.poll(:idle_timeout => SimpleMessageQueue.configuration.idle_timeout, :wait_time_seconds => SimpleMessageQueue.configuration.wait_time_seconds) do |message|
      @count += 1
      process_message(message)
    end
    @count
  end

  def process_message(message)
    raise SimpleMessageQueue::NotImplementedError.new(name)
  end

end
