# coding: utf-8
require "redis-search"
namespace :redis_search do
  task index: 'index:all'

  namespace :index do
    index_model_desc = <<-DESC.gsub(/      /, '')
      Redis-Search index data to Redis from your model (pass name as CLASS environment variable).

        $ rake environment redis_search:index:model CLASS='MyModel'

      Customize the batch size:

        $ rake environment redis_search:index:model CLASS='Article' BATCH=100
    DESC

    index_all_desc = <<-DESC.gsub(/      /, '')
      Redis-Search all index data to Redis from `app/models` (or use DIR environment variabl).

        $ rake environment redis_search:index:all DIR=app/models

      Customize the batch size:

        $ rake environment redis_search:index:all DIR=app/models BATCH=100
    DESC

    desc index_model_desc
    task model: :environment do
      if ENV['CLASS'].to_s == ''
        puts '='*90, 'USAGE', '='*90, index_model_desc, ""
        exit(1)
      end

      klass = eval(ENV['CLASS'].to_s)
      batch = ENV['BATCH'].to_i > 0 ? ENV['BATCH'].to_i : 1000
      tm    = Time.now
      puts "Redis-Search index data to Redis from [#{klass.to_s}]"
      count = klass.redis_search_index_batch_create(batch, true)
      puts ""
      puts "Indexed #{count} rows  |  Time spend: #{(Time.now - tm)}s"
      puts "Rebuild Index done."
    end

    desc index_all_desc
    task all: :environment do
      tm    = Time.now
      count = 0
      dir   = ENV['DIR'].to_s != '' ? ENV['DIR'] : 'app/models'
      batch = ENV['BATCH'].to_i > 0 ? ENV['BATCH'].to_i : 1000

      Dir.glob(File.join("#{dir}/**/*.rb")).each do |path|
        model_filename = path[/#{Regexp.escape(dir.to_s)}\/([^\.]+).rb/, 1]

        next if model_filename.match(/^concerns\//i) # Skip concerns/ folder

        begin
          klass = model_filename.camelize.constantize
        rescue NameError
          require(path) ? retry : raise(RuntimeError, "Cannot load class '#{klass}'")
        end
      end

      puts "Redis-Search index data to Redis from [#{dir}]"
      Redis::Search.indexed_models.each do |klass|
        puts "[#{klass.to_s}]"
        count += klass.redis_search_index_batch_create(batch, true)
        puts ""
      end
      puts "Indexed #{count} rows  |  Time spend: #{(Time.now - tm)}s"
      puts "Rebuild Index done."
    end
  end
end
