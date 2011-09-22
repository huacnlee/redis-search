# coding: utf-8
class Redis
  module Search
    class << self
      attr_accessor :config, :indexed_models
    
      def configure
        yield self.config ||= Config.new
      end
    end
  
    class Config
      # Redis 
      attr_accessor :redis
      # Debug toggle
      attr_accessor :debug
      # config for max length of content with Redis::Search.complete method，default 100
      # Please change this with your real data length, short is fast
      # For example: You use complete search for your User model name field, and the "name" as max length in 15 chars, then you can set here to 15
      # warring! The long content will can't be found, if the config length less than real content.
      attr_accessor :complete_max_length
    
      def initialize
        self.debug = false
        self.redis = nil
        self.complete_max_length = 100
      end
    end
  end
end