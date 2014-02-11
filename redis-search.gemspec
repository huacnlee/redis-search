# coding: utf-8
Gem::Specification.new do |s|
  s.name        = "redis-search"
  s.version     = "0.9.3"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Jason Lee"]
  s.email       = ["huacnlee@gmail.com"]
  s.homepage    = "http://github.com/huacnlee/redis-search"
  s.summary     = "High performance real-time search (Support Chinese), index in Redis for Rails application."
  s.description = "High performance real-time search (Support Chinese), index in Redis for Rails application. "
  s.license     = 'MIT'
  s.required_rubygems_version = ">= 1.3.6"

  s.add_runtime_dependency("ruby-pinyin", '~> 0.3', '>= 0.3.0')
  s.add_runtime_dependency("redis-namespace", ">= 1.0.2")
  s.add_runtime_dependency("redis", ">= 2.1.1")

  s.files        = Dir.glob("lib/**/*") + %w(README.md LICENSE)
  s.require_path = 'lib'
end
