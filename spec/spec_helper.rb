require 'rubygems'


ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __FILE__)
require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))


require 'active_support/all'
require 'rspec'
require 'rspec/autorun'
require "redis"
require "redis-search"
require "redis-namespace"
require "mongoid"
require "mocha"

Mongoid.configure do |config|
  name = "redis_search_test"
  host = "localhost"
  config.master = Mongo::Connection.new.db(name)
end

require "models"

# Config Redis::Search
$redis = Redis.new(:host => "127.0.0.1",:port => "6379")
$redis = Redis::Namespace.new("redis_search_test", :redis => $redis)
Redis::Search.configure do |config|
  config.redis = $redis
  config.complete_max_length = 100
  config.pinyin_match = true
end

Rspec.configure do |config|
  config.mock_with :mocha
  config.after :suite do
    Mongoid.master.collections.select {|c| c.name !~ /system/ }.each(&:drop)
    keys = $redis.keys("*")
    $redis.del(*keys)
  end
end