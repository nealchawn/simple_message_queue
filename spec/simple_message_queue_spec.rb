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


  describe 'configuration is empty' do
    before do
      if SimpleMessageQueue.configuration
        SimpleMessageQueue.configuration = nil
      end
    end

    it 'should raise SimpleMessageQueue::ConfigurationError without a configuration' do
      proc { DummyQueue.sqs }.must_raise SimpleMessageQueue::ConfigurationError
    end

  end

  describe 'configuration is not empty' do
    before do
      unless SimpleMessageQueue.configuration
        c = YAML::load_file(File.join(File.dirname(File.expand_path(__FILE__)), '../lib/config.yml'))
        SimpleMessageQueue.configure { |config| config.access_key_id = c['AWS']['access_key_id']; config.secret_access_key= c['AWS']['secret_access_key'] }
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
      queue_name.must_equal 'dummy_queue'
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

    it 'should send a message to the queue' do
      original_count = DummyQueue.count
      sent_message = DummyQueue.send('test')

      # We can't accurately test the count of the queue. This is due to AWS constraints, sometimes a message does not show up in the queue for 60 seconds
      # DummyQueue.count.must_equal original_count + 1
      sent_message.must_be_kind_of AWS::SQS::Queue::SentMessage
    end

    it 'should receive a message from the queue' do
      # Give this test a logger so that the standard logger (STDOUT) won't affect test output
      dummy_queue_log = 'dummy_queue_with_process_message.log'
      SimpleMessageQueue.configure { |config| config.logger = Logger.new(dummy_queue_log) }

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

      SimpleMessageQueue.configure { |config| config.logger = Logger.new(dummy_queue_log) }

      DummyQueue.logger.info message
      File.exist?(dummy_queue_log).must_equal true
      File.open(dummy_queue_log).read().index(message).wont_be_nil
    end

  end

  
  MiniTest.after_run do
    DummyQueue.delete_queue if DummyQueue.exists?
    AnotherDummyQueue.delete_queue if AnotherDummyQueue.exists?
    DummyQueueWithProcessMessage.delete_queue if DummyQueueWithProcessMessage.exists?
    DummyQueueToDelete.delete_queue if DummyQueueToDelete.exists?
    DummyQueueToCreateQueue.delete_queue if DummyQueueToCreateQueue.exists?
    File.delete('dummy_queue.log') if File.exist?('dummy_queue.log')
    File.delete('dummy_queue_with_process_message.log') if File.exist?('dummy_queue_with_process_message.log')
    puts $debug_info
  end

end

