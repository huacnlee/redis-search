# Redis-Search

High performance real-time prefix search, indexes store in Redis for Rails application.

[中文介绍和使用说明](https://github.com/huacnlee/redis-search/wiki/Usage-in-Chinese)

## Master Status

[![Gem Version](https://badge.fury.io/rb/redis-search.svg)](https://badge.fury.io/rb/redis-search) [![CI Status](https://secure.travis-ci.org/huacnlee/redis-search.svg)](http://travis-ci.org/huacnlee/redis-search) [![CodeCov](https://codecov.io/gh/huacnlee/redis-search/branch/master/graph/badge.svg)](https://codecov.io/gh/huacnlee/redis-search)


## Features

* Real-time search
* High performance
* Prefix match search
* Support match with alias
* Support ActiveRecord and Mongoid
* Sort results by one field
* Homophone search, pinyin search
* Search as pinyin first chars
* Conditions support

## Requirements

* Redis 2.2+

## Install

```ruby
gem 'redis-search'
```

```bash
$ bundle install
```

## Configure

* Create file in: config/initializers/redis-search.rb

```ruby
require "redis"
require "redis-namespace"
require "redis-search"

# don't forget change namespace
redis = Redis.new(host: '127.0.0.1', port: '6379')
# We suggest you use a special db in Redis, when you need to clear all data, you can use `flushdb` command to cleanup.
redis.select(3)
# Give a special namespace as prefix for Redis key, when your have more than one project used redis-search, this config will make them work fine.
redis = Redis::Namespace.new("your_app_name:redis_search", redis: redis)
Redis::Search.configure do |config|
  config.redis = redis
  config.complete_max_length = 100
  config.pinyin_match = true
end
```

## Usage

* Bind `Redis::Search` callback event, it will to rebuild search indices when data create or update.

```ruby
class Post < ActiveRecord::Base
  include Redis::Search

  belongs_to :user
  belongs_to :category

  redis_search title_field: :title,
               score_field: :hits,
               condition_fields: [:user_id, :category_id],
               ext_fields: [:category_name]

  def category_name
    self.category.name
  end
end
```

```ruby
class User < ActiveRecord::Base
  include Redis::Search

  serialize :alias_names, Array

  redis_search title_field: :name,
               alias_field: :alias_names,
               score_field: :followers_count,
               ext_fields: [:email, :tagline]
end
```

```ruby
class SearchController < ApplicationController
  # GET /search_users?q=j
  def search_users
    Post.prefix_match(params[:q], conditions: { user_id: 12, category_id: 4 })
  end
end
```

## Index data to Redis

### Specify Model

Redis-Search index data to Redis from your model (pass name as CLASS environment variable).

```bash
$ rake redis_search:index:model CLASS='User'
```

Customize the batch size:

```bash
$ rake redis_search:index:model CLASS='User' BATCH=100
```

### All Models

Redis-Search all index data to Redis from `app/models` (or use DIR environment variabl).

```bash
$ rake redis_search:index DIR=app/models
```

Customize the batch size:

```bash
$ rake redis_search:index DIR=app/models BATCH=100
```

## Documentation

* See [Rdoc.info redis-search](http://rubydoc.info/gems/redis-search)
* [Example App](https://github.com/huacnlee/redis-search-example)

## Benchmark test

You can run the rake command (see Rakefile) to make test.
There is my performance test result.

* [https://gist.github.com/1150933](https://gist.github.com/1150933)

## Demo

![](http://l.ruby-china.org/photo/34368688ee1c1928c2841eb2f41306ec.png)

Projects used redis-search:

- [redis-search-example](https://github.com/huacnlee/redis-search-example) - An example for show you how to use redis-search.
- [IMAX.im](https://github.com/huacnlee/imax.im)

## License

* MIT
