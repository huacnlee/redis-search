# coding: utf-8
require "redis_search/base"
require "redis_search/search"
require "redis_search/config"

module RedisSearch
  class << self
    def configure
      yield self.config ||= Config.new
    end
  end
end