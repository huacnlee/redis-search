ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', File.dirname(__FILE__))
require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rails/all'
require 'sqlite3'
require 'redis'
require 'redis-namespace'
require 'mocha'
require 'uri'
require 'database_cleaner'
require 'ruby-pinyin'

require 'simplecov'
if ENV['CI'] == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end
SimpleCov.start 'rails' do
  add_filter 'lib/redis-search/version'
end

PinYin.backend = PinYin::Backend::Simple.new

require 'redis-search'

# ActiveRecord::Base.logger = Logger.new(STDOUT)
ActiveRecord::Base.establish_connection adapter: 'sqlite3', database: ':memory:'
# ActiveRecord::Base.configurations = true

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define(version: 1) do
  create_table :posts do |t|
    t.string :title, null: false
    t.text :alias
    t.text :body
    t.integer :user_id
    t.integer :category_id
    t.integer :hits, default: 0
    t.datetime :created_at
    t.datetime :updated_at
  end

  create_table :users do |t|
    t.string :type
    t.string :email
    t.string :name
    t.string :password
    t.text :alias
    t.integer :score
    t.integer :gender, default: 0
    t.datetime :created_at
    t.datetime :updated_at
  end

  create_table :categories do |t|
    t.string :name
    t.datetime :created_at
    t.datetime :updated_at
  end

  create_table :companies do |t|
    t.string :name
    t.string :type
    t.datetime :created_at
    t.datetime :updated_at
  end
end
require 'models'

# Config Redis::Search
redis_config = YAML.load_file(File.join(File.dirname(__FILE__), 'redis.yml'))['test']
$redis = Redis.new(host: redis_config['host'], port: redis_config['port'])
$redis = Redis::Namespace.new('redis_search_test', redis: $redis)
Redis::Search.configure do |config|
  config.redis = $redis
  config.complete_max_length = 100
  config.pinyin_match = true
end

RSpec.configure do |config|
  config.mock_with :mocha
  config.after(:all) do
    keys = $redis.keys('*')
    if keys.length > 1
      keys.each_slice(1000) do |sub_keys|
        $redis.del(*sub_keys)
      end
    end
  end

  config.before(:each) do
    DatabaseCleaner.orm = :active_record
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
  end
end

class RandomWord
  attr_accessor :word_dict, :size
  def initialize
    self.word_dict = File.open('/usr/share/dict/words').read.split("\n")
    self.size = word_dict.count
  end

  def next(words = 2, length = 23)
    name = 'a' * (length + 1)
    while name.length > length
      name = (1..words).map do |_i|
        word_dict[rand(size)].chomp.capitalize
      end.join(' ')
    end
    name
  end
end
