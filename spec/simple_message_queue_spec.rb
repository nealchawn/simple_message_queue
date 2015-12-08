gem 'minitest'
require 'minitest/autorun'

require 'simple_message_queue'
require 'yaml'

describe SimpleMessageQueue do

  # Create DummyQueues extending SimpleMessageQueue so that we can test all of the functionality of the module
  class DummyQueue
    extend SimpleMessageQueue
  end

  class AnotherDummyQueue
    extend SimpleMessageQueue
  end

  class DummyQueueWithProcessMessage
    extend SimpleMessageQueue

    def self.process_message(message)
      return true
    end
  end

  class DummyQueueToDelete
    extend SimpleMessageQueue
  end

  class DummyQueueToCreateQueue
    extend SimpleMessageQueue
  end

  class DummyQueueToOverwriteQueueName
    extend SimpleMessageQueue
  end


  describe 'configuration is empty' do
    before do
      if SimpleMessageQueue.configuration
        SimpleMessageQueue.configuration = nil
      end
    end

    it 'should raise SimpleMessageQueue::ConfigurationError without a configuration' do
      proc { DummyQueue.sqs }.must_raise SimpleMessageQueue::ConfigurationError
    end

    it 'should raise SimpleMessageQueue::EnvironmentError without a valid environment' do
      proc { DummyQueue.queue_name }.must_raise SimpleMessageQueue::EnvironmentError
    end
  end

  describe 'configuration is not empty' do
    before do
      unless SimpleMessageQueue.configuration
        c = YAML::load_file(File.join(File.dirname(File.expand_path(__FILE__)), '../lib/config.yml'))
        SimpleMessageQueue.configure { |config| config.access_key_id = c['AWS']['access_key_id']; config.secret_access_key= c['AWS']['secret_access_key']; config.environment = 'test' }
      end
    end

    it 'should connect to aws sqs on the first call' do
      sqs = DummyQueue.sqs
      sqs.wont_be_nil
    end

    it 'should not make another connection to aws sqs on additional calls' do
      sqs1 = DummyQueue.sqs
      sqs2 = AnotherDummyQueue.sqs
      sqs1.object_id.must_be_same_as sqs2.object_id
    end

    it 'should create a queue if the queue does not already exist' do
      DummyQueueToCreateQueue.exists?.must_equal false
      queue = DummyQueueToCreateQueue.queue
      queue.must_be_kind_of AWS::SQS::Queue
    end

    it 'should generate the correct queue_name' do
      queue_name = DummyQueue.queue_name
      queue_name.must_equal 'dummy_queue_test'
    end

    it 'should allow you to overwrite the queue_name' do
      DummyQueueToOverwriteQueueName.class_eval do
        @queue_name = 'new_queue_name'
      end
      queue_name = DummyQueueToOverwriteQueueName.queue_name
      queue_name.must_equal 'new_queue_name_test'
    end

    it 'should return a queue' do
      queue = DummyQueue.queue
      queue.must_be_kind_of AWS::SQS::Queue
    end

    it 'should delete a queue' do
      # This method will fail if tests are run more than once every 60 seconds
      # This is due to AWS constraints. After deleting a queue, you must wait 60 seconds before creating another queue with the same name
      queue = DummyQueueToDelete.queue
      queue.wont_be_nil
      DummyQueueToDelete.delete_queue
      DummyQueueToDelete.exists?.must_equal false, "[Note:] Every once and a while this test will fail. This is due to AWS's latency. Since we delete the queue and then test for it's existence directly afterwards, it MAY still appear to exists for up to 60 seconds, resulting in the test failing"
    end

    it 'should_send_a_message_to the queue' do
      original_count = DummyQueue.count
      sent_message = DummyQueue.send('test')

      # We can't accurately test the count of the queue. This is due to AWS constraints, sometimes a message does not show up in the queue for 60 seconds
      # DummyQueue.count.must_equal original_count + 1
      sent_message.must_be_kind_of AWS::SQS::Queue::SentMessage
    end

    it 'should receive a message from the queue' do
      # Give this test a logger so that the standard logger (STDOUT) won't affect test output
      dummy_queue_with_process_message_log = 'dummy_queue_with_process_message.log'
      SimpleMessageQueue.configure { |config| config.logger = nil; config.logger = Logger.new(dummy_queue_with_process_message_log) }

      DummyQueueWithProcessMessage.send('test message')
      count = DummyQueueWithProcessMessage.receive
      count.must_be :>, 0
    end

    it 'should raise SimpleMessageQueue::NotImplementedError if process_message is not defined for the extending model' do
      sent_message = DummyQueue.send('test')
      proc { DummyQueue.process_message(sent_message) }.must_raise SimpleMessageQueue::NotImplementedError
    end

    it 'should accept a logger as a configuration option and then use that logger' do
      message = 'Sample Log Message'
      dummy_queue_log = 'dummy_queue.log'

      SimpleMessageQueue.configure { |config| config.logger = nil; config.logger = Logger.new(dummy_queue_log) }

      DummyQueue.logger.info message
      File.exist?(dummy_queue_log).must_equal true
      File.open(dummy_queue_log).read().index(message).wont_be_nil
    end

    it 'should log an error on message send failure' do
      dummy_queue_with_message_send_failure_log = 'dummy_queue_with_message_send_failure.log'

      SimpleMessageQueue.configure { |config| config.logger = nil; config.logger = Logger.new(dummy_queue_with_message_send_failure_log) }

      DummyQueue.send(12345)    # Send only accepts strings. Sending an integer will cause the send to fail
      File.exist?(dummy_queue_with_message_send_failure_log).must_equal true
      #puts 'looking for index of "There was an error when sending an item to"'
      #puts File.open(dummy_queue_log).read().index('There was an error when sending an item to')
      File.open(dummy_queue_with_message_send_failure_log).read().index('There was an error when sending an item to').wont_be_nil
    end

    describe 'notifications' do
      before do
        SimpleMessageQueue.configure { |config| config.sns_notifications = true; config.sns_notification_prefix = 'prefix' }
      end

      it 'should create the topics after configuration' do
        # Change the sns_notification_prefix so we can make sure a topic is created on configuration
        SimpleMessageQueue.configure { |config| config.sns_notifications = true; config.sns_notification_prefix = 'test_prefix' }

        topic = SimpleMessageQueue::Notification::Topic.find('send_message_failure')
        topic.sns_topic.wont_be_nil
        topic.name.must_equal 'test_prefix_send_message_failure_test'
        # Set the sns_notification_prefix back to what is set in the before block
        SimpleMessageQueue.configure { |config| config.sns_notifications = true; config.sns_notification_prefix = 'prefix' }
      end

      it 'should create a topic' do
        topic = SimpleMessageQueue::Notification::Topic.new('dummy_topic')
        topic.sns_topic.must_be_kind_of AWS::SNS::Topic
      end

      it 'should create a topic with the environment appended to the name' do
        topic = SimpleMessageQueue::Notification::Topic.new('dummy_topic_with_environment')
        regex = "dummy_topic_with_environment_#{SimpleMessageQueue.configuration.environment}"
        topic.name.must_match /#{regex}/
      end

      it 'should create a topic with the sns_notification_prefix prepended to the name if sns_notification_prefix is defined' do
        topic = SimpleMessageQueue::Notification::Topic.new('dummy_topic_with_prefix')
        regex = "#{SimpleMessageQueue.configuration.sns_notification_prefix}_dummy_topic_with_prefix"
        topic.name.must_match /#{regex}/
      end

      it 'should send a message to the topic' do
        topic = SimpleMessageQueue::Notification::Topic.new('dummy_topic')
        response = topic.send('test_message')
        response.must_be_kind_of AWS::Core::Response
        response.message_id.wont_be_nil
      end

      it 'should delete a topic' do
        topic = SimpleMessageQueue::Notification::Topic.new('dummy_topic_for_deletion')
        topic.sns_topic.must_be_kind_of AWS::SNS::Topic

        topic.delete
        deleted_topic = SimpleMessageQueue::Notification::Topic.find_by_full_name(topic.name)
        deleted_topic.must_be_nil
      end

      it 'should be able to find a topic by name' do
        topic = SimpleMessageQueue::Notification::Topic.find('send_message_failure')
        topic.wont_be_nil
      end

      it 'should send a notification on message send failure' do
        response = DummyQueue.send(12345)    # Send only accepts strings. Sending an integer will cause the send to fail
        response.must_be_kind_of AWS::Core::Response
        response.message_id.wont_be_nil
      end
    end
  end
  
  MiniTest.after_run do
    # Clean up queues created for tests
    DummyQueue.delete_queue if DummyQueue.exists?
    AnotherDummyQueue.delete_queue if AnotherDummyQueue.exists?
    DummyQueueWithProcessMessage.delete_queue if DummyQueueWithProcessMessage.exists?
    DummyQueueToDelete.delete_queue if DummyQueueToDelete.exists?
    DummyQueueToCreateQueue.delete_queue if DummyQueueToCreateQueue.exists?
    DummyQueueToOverwriteQueueName.delete_queue if DummyQueueToOverwriteQueueName.exists?
    
    # Clean up logs created for tests
    File.delete('dummy_queue.log') if File.exist?('dummy_queue.log')
    File.delete('dummy_queue_with_process_message.log') if File.exist?('dummy_queue_with_process_message.log')
    File.delete('dummy_queue_with_message_send_failure.log') if File.exist?('dummy_queue_with_message_send_failure.log')

    # Clean up SNS Topics created for tests
    SimpleMessageQueue::Notification::Topic.find_by_full_name('test_prefix_send_message_failure_test').delete
    SimpleMessageQueue::Notification::Topic.find_by_full_name('prefix_send_message_failure_test').delete
    SimpleMessageQueue::Notification::Topic.find('dummy_topic').delete
    # SimpleMessageQueue::Notification::Topic.find('dummy_topic_for_deletion').delete
    SimpleMessageQueue::Notification::Topic.find('dummy_topic_with_environment').delete
    SimpleMessageQueue::Notification::Topic.find('dummy_topic_with_prefix').delete

    puts $debug_info
  end

end
