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

# These environment variables can be set if wanting to test against a database
# that is not on the local machine.
ENV["MONGOID_SPEC_HOST"] ||= "localhost"
ENV["MONGOID_SPEC_PORT"] ||= "27017"

# These are used when creating any connection in the test suite.
HOST = ENV["MONGOID_SPEC_HOST"]
PORT = ENV["MONGOID_SPEC_PORT"].to_i

def database_id
  ENV["CI"] ? "redis_search_#{Process.pid}" : "redis_search_test"
end

# Set the database that the spec suite connects to.
Mongoid.configure do |config|
  config.connect_to(database_id)
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
    Mongoid.purge!
    Mongoid::IdentityMap.clear
    if ENV["CI"]
      Mongoid::Threaded.sessions[:default].drop
    end
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