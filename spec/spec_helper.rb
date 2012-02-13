require 'rubygems'


ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __FILE__)
require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'active_support/all'
require "redis"
require "redis-search"
require "redis-namespace"
require "mongoid"
require "mocha"
require "uri"

mongoid_config = YAML.load_file(File.join(File.dirname(__FILE__),"mongoid.yml"))['test']
Mongoid.configure do |config|
  if !mongoid_config['uri'].blank?
    config.master = Mongo::Connection.from_uri(mongoid_config['uri']).db(mongoid_config['uri'].split('/').last)
  else
    config.master = Mongo::Connection.new(mongoid_config['host'], mongoid_config['port']).db(mongoid_config['database'])
  end
end

require "models"

# Config Redis::Search
redis_config = YAML.load_file(File.join(File.dirname(__FILE__),"redis.yml"))['test']
if !redis_config['uri'].blank?
  uri = URI.parse(redis_config['uri'])
  $redis = Redis.new(:host => uri.host,:port => uri.port, :password => uri.password)
else
  $redis = Redis.new(:host => redis_config['host'],:port => redis_config['port'])
end
$redis = Redis::Namespace.new("redis_search_test", :redis => $redis)
Redis::Search.configure do |config|
  config.redis = $redis
  config.complete_max_length = 100
  config.pinyin_match = true
end

RSpec.configure do |config|
  config.mock_with :mocha
  config.after :suite do
    Mongoid.master.collections.select {|c| c.name !~ /system/ }.each(&:drop)
    keys = $redis.keys("*")
    if keys.length > 1
      $redis.del(*keys)
    end
  end
end

class RandomWord
  attr_accessor :word_dict, :size
  def initialize
    path = "/usr/share/dict/words"
    self.word_dict = File.open("/usr/share/dict/words").read.split("\n")
    self.size = self.word_dict.count
  end
  
  def next(words = 2, length = 23)
    name = 'a'*(length+1)
    while name.length > length
      name = (1..words).map{ |i| self.word_dict[rand(self.size)].chomp.capitalize }.join(" ")
    end
    name
  end
end