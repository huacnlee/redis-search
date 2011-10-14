require 'rake'
require "rspec"
require File.expand_path('../spec/spec_helper', __FILE__)

task :default do
  system 'bundle exec rspec spec'
end



namespace :benchmark do
  task :random_words do
    random = RandomWord.new
    Benchmark.bm do|bm|
      bm.report("Generate 1 random words") do
        1.times do |i|
          name = random.next
        end
      end
      
      bm.report("Generate 100 random words") do
        100.times do |i|
          name = random.next
        end
      end
      
      bm.report("Generate 10,000 random words") do
        10_000.times do |i|
          name = random.next
        end
      end
      
      bm.report("Generate 100,000 random words") do
        100_000.times do |i|
          name = random.next
        end
      end
      
      bm.report("Generate 1,000,000 random words") do
        1_000_000.times do |i|
          name = random.next
        end
      end
    end
  end
  
  task :index_categories do
    random = RandomWord.new
    Benchmark.bm do|bm|
      bm.report("Index 1,000,000 categories data ") do
        1_000_000.times do |i|
          Redis::Search::Index.new(:type => "CategoryTest",
                                  :title => random.next, 
                                  :id => BSON::ObjectId.new,
                                  :prefix_index_enable => true,
                                  :score => 1).save
        end
      end
    end
  end
  
  task :complete do
    keys_count = $redis.dbsize
    puts "Complete Benchmark from [CategoryTest], current have (#{keys_count} keys) in Redis"
    ["c","ca","can","jack"].each do |q|
      puts "Search by [#{q}]"
      puts "    #{'-'*90}"
      puts "    #{Redis::Search.complete("CategoryTest",q, :limit => 10).collect { |c| [c['id'],c['title']].join(':') }}"
      puts "    #{'-'*90}"
      puts "There have [#{Redis::Search.complete("CategoryTest",q, :limit => 1000000).count}] items like '#{q}'"
    
      Benchmark.bm do|bm|
        bm.report("    1 times") do
          1.times do |i|
            Redis::Search.complete("CategoryTest",q, :limit => 10)
          end
        end
      
        bm.report("    10 times") do
          10.times do |i|
            Redis::Search.complete("CategoryTest",q, :limit => 10)
          end
        end
      
        bm.report("    100 times") do
          100.times do |i|
            Redis::Search.complete("CategoryTest",q, :limit => 10)
          end
        end
      end
      puts ""
    end
  end
  
  task :query do
    keys_count = $redis.dbsize
    puts "Query Benchmark from [CategoryTest], current have (#{keys_count} keys) in Redis"
    ["Cabalic","Latcher","Pectolite","Jackal"].each do |q|
      puts "Search by [#{q}]"
      puts "    #{'-'*90}"
      puts "    #{Redis::Search.query("CategoryTest",q, :limit => 10).collect { |c| [c['id'],c['title']].join(':') }}"
      puts "    #{'-'*90}"
      puts "There have [#{Redis::Search.query("CategoryTest",q, :limit => 1000000).count}] items like '#{q}'"
    
      Benchmark.bm do|bm|
        bm.report("    1 times") do
          1.times do |i|
            Redis::Search.query("CategoryTest",q, :limit => 10)
          end
        end
      
        bm.report("    10 times") do
          10.times do |i|
            Redis::Search.query("CategoryTest",q, :limit => 10)
          end
        end
      
        bm.report("    100 times") do
          100.times do |i|
            Redis::Search.query("CategoryTest",q, :limit => 10)
          end
        end
      end
      puts ""
    end
  end
end