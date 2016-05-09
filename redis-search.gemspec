$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'redis-search/version'

Gem::Specification.new do |s|
  s.name        = 'redis-search'
  s.version     = Redis::Search::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Jason Lee']
  s.email       = ['huacnlee@gmail.com']
  s.homepage    = 'http://github.com/huacnlee/redis-search'
  s.summary     = 'High performance real-time prefix search.'
  s.description = 'High performance real-time prefix search, indexes store in Redis for Rails application.'
  s.license     = 'MIT'

  s.add_runtime_dependency('ruby-pinyin', '~> 0.3', '>= 0.3.0')
  s.add_runtime_dependency('redis-namespace', '>= 1.3.0')
  s.add_runtime_dependency('redis', '>= 3.0.0')

  s.files        = Dir.glob('lib/**/*') + %w(README.md LICENSE)
  s.require_path = 'lib'
end
