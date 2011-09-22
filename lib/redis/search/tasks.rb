# coding: utf-8
require "redis-search"
namespace :redis_search do
  desc "Redis-Search index data to Redis"
  task :index => :environment do
    tm = Time.now
    count = 0
    puts "redis-search index".upcase.rjust(120)
    puts "-"*120
    puts "Now indexing search to Redis...".rjust(120)
    puts ""
    Redis::Search.indexed_models.each do |klass|
      print "[#{klass.to_s}]"
      if klass.superclass.to_s == "ActiveRecord::Base"
        klass.find_in_batches(:batch_size => 1000) do |items|
          items.each do |item|
            item.redis_search_index_create
      			item = nil
      			count += 1
            print "."
          end
        end
      elsif klass.included_modules.collect { |m| m.to_s }.include?("Mongoid::Document")
        klass.all.each do |item|
          item.redis_search_index_create
    			item = nil
    			count += 1
          print "."
        end
      else
        puts "skiped, not support this ORM in current."
      end
      puts ""
    end
    puts ""
    puts "-"*120
    puts "Indexed #{count} rows  |  Time spend: #{(Time.now - tm)}s".rjust(120)
    puts "Rebuild Index done.".rjust(120)
  end
end