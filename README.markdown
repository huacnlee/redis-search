# RedisSearch

High performance real-time search (Support Chinese), index in Redis for Rails application

## Features

* Real-time search
* High performance

## Requirements

* Redis 2.2
* Libmmseg

## Install

in Rails application Gemfile

		gem 'redis','2.1.1'
		gem "rmmseg-cpp-huacnlee", "0.2.8"
		gem 'redis-search', '0.1'

install bundlers

		$ bundle install

## Configure

create file in: config/initializers/redis_search.rb

    require "redis_search"
    redis = Redis.new(:host => "127.0.0.1",:port => "6379")
		# change redis database to 3
    redis.select(3)
    RedisSearch.configure do |config|
     config.redis = redis
    end

## Usage

bind RedisSearch callback event, it will to rebuild search indexes when data create or update.

    class Post
      include Mongoid::Document
      include RedisSearch
  
      field :title
      field :body
  
      belongs_to :user
      belongs_to :category
  
      redis_search_index(:title_field => :title,
                         :ext_fields => [:category_name])
  
      def category_name
        self.category.name
      end
    end

    # GET /searchs?q=title
    class SearchController < ApplicationController
      def index
        RedisSearch::Search.query(params[:q], :type => "Post")
      end
    end
    
## Demo

You can try the search feature in [`zheye.org`](http://zheye.org)
