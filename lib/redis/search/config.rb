# coding: utf-8
class Redis
  module Search
    class << self
      attr_accessor :config, :indexed_models

      def configure
        yield @config ||= Config.new

        if not @config.disable_rmmseg
          require "rmmseg"
          # loading RMMSeg chinese word dicts.
          RMMSeg::Dictionary.load_dictionaries
        end
      end
    end

    class Config
      # Redis
      attr_accessor :redis
      # Debug toggle, default false
      attr_accessor :debug
      # config for max length of content with Redis::Search.complete method，default 100
      # Please change this with your real data length, short is fast
      # For example: You use complete search for your User model name field, and the "name" as max length in 15 chars, then you can set here to 15
      # warring! The long content will can't be found, if the config length less than real content.
      attr_accessor :complete_max_length
      # Pinyin search/index (true|false) - default = false
      # If set this is true, the indexer will convert Chinese to Pinyin, and index them
      # When you search "de" will -> 得|的|德...
      # When you search "得" will -> "de" -> 得|的|德...
      attr_accessor :pinyin_match
      # Disable RMMSeg, if you don't need, disable this will save memory. (true|false) default = true
      attr_accessor :disable_rmmseg

      def initialize
        @debug               = false
        @redis               = nil
        @complete_max_length = 100
        @pinyin_match        = false
        @disable_rmmseg      = false
      end
    end
  end
end
