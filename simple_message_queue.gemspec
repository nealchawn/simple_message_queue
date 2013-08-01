$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "simple_message_queue/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "simple_message_queue"
  s.version     = SimpleMessageQueue::VERSION
  s.authors     = ["Jim Smith"]
  s.email       = ["jim@jimsmithdesign.com"]
  s.homepage    = "https://github.com/cbi/simple_message_queue"
  s.summary     = "SimpleMessageQueue"
  s.description = "SimpleMessageQueue is a simple interface for Amazon Web Service's SQS."
  s.license     = 'MIT'

  s.files = Dir["{app,config,db,lib}/**/*"] + ["README.md"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency 'aws-sdk'
  s.add_dependency 'minitest'
end
