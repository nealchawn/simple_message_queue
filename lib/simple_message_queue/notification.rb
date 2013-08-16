module SimpleMessageQueue
  class Notification

    class << self
      
      def sns
        raise SimpleMessageQueue::ConfigurationError unless SimpleMessageQueue.configuration
        raise SimpleMessageQueue::EnvironmentError unless defined?(SimpleMessageQueue.configuration.environment)
        @@sns ||= AWS::SNS.new(:access_key_id => SimpleMessageQueue.configuration.access_key_id, :secret_access_key => SimpleMessageQueue.configuration.secret_access_key)
      end

    end

    class Topic

      attr_reader :sns_topic

      class << self
        def find(name)
          topic_name = topic_name(name)
          sns_topic = SimpleMessageQueue::Notification.sns.topics.find { |t| t.name == topic_name }
          topic = (sns_topic) ? Topic.new(sns_topic.name, false) : nil
        end

        def find_by_full_name(full_name)
          sns_topic = SimpleMessageQueue::Notification.sns.topics.find { |t| t.name == full_name }
          topic = (sns_topic) ? Topic.new(sns_topic.name, false) : nil
        end

        def topic_name(name)
          if defined?(SimpleMessageQueue.configuration.sns_notification_prefix) && !SimpleMessageQueue.configuration.sns_notification_prefix.nil?
            topic_name = "#{SimpleMessageQueue.configuration.sns_notification_prefix}_#{name}_#{SimpleMessageQueue.configuration.environment}"
          else
            topic_name = "#{name}_#{SimpleMessageQueue.configuration.environment}"
          end
          topic_name
        end
      end

      def sns
        SimpleMessageQueue::Notification.sns
      end

      def initialize(name, generate_topic_name=true)
        raise SimpleMessageQueue::ConfigurationError unless SimpleMessageQueue.configuration
        raise SimpleMessageQueue::EnvironmentError unless defined?(SimpleMessageQueue.configuration.environment)

        topic_name = (generate_topic_name) ? self.class.topic_name(name) : name
        @sns_topic = sns.topics.create(topic_name)
      end

      def name
        @sns_topic.name
      end

      def send(message, subject=nil)
        message_hash = {
          topic_arn: @sns_topic.arn,
          message: message
        }
        message_hash[:subject] = subject if subject
        sns.client.publish(message_hash)
      end

      def delete
        @sns_topic.delete
      end

    end

  end
end
