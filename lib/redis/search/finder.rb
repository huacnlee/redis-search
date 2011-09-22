# coding: utf-8
require "rmmseg"
class Redis
  module Search
    def self.split(text)
      algor = RMMSeg::Algorithm.new(text)
      words = []
      loop do
        tok = algor.next_token
        break if tok.nil?
        words << tok.text
      end
      words
    end
    
    def self.warn(msg)
      puts "[Redis::Search][warn]: #{msg}"
    end
  
    # 生成 uuid，用于作为 hashes 的 field, sets 关键词的值
    def self.mk_sets_key(type, key)
      "#{type}:#{key.downcase}"
    end
  
    def self.mk_complete_key(type)
      "Compl#{type}"
    end

    # Use for short title search, this method is search by chars, for example Tag, User, Category ...
    # 
    # h3. params:
    #   type      model name
    #   w         search char
    #   :limit    result limit
    # h3. usage:
    # * Redis::Search.complete("Tag","r") => ["Ruby","Rails", "REST", "Redis", "Redmine"]
    # * Redis::Search.complete("Tag","re") => ["Redis", "Redmine"]
    # * Redis::Search.complete("Tag","red") => ["Redis", "Redmine"]
    # * Redis::Search.complete("Tag","redi") => ["Redis"]
    def self.complete(type, w, options = {})
      limit = options[:limit] || 10 

      prefix_matchs = []
      # This is not random, try to get replies < MTU size
      rangelen = Redis::Search.config.complete_max_length
      prefix = w.downcase
      key = Search.mk_complete_key(type)
      
      start = Redis::Search.config.redis.zrank(key,prefix)
      return [] if !start
      count = limit
      max_range = start+(rangelen*limit)-1
      range = Redis::Search.config.redis.zrange(key,start,max_range)
      while prefix_matchs.length <= count
        start += rangelen
        break if !range or range.length == 0
        range.each {|entry|
          minlen = [entry.length,prefix.length].min
          if entry[0...minlen] != prefix[0...minlen]
            count = prefix_matchs.count
            break
          end
          if entry[-1..-1] == "*" and prefix_matchs.length != count
            prefix_matchs << entry[0...-1]
          end
        }
        range = range[start..max_range]
      end
      words = []
      words = prefix_matchs.uniq.collect { |w| Search.mk_sets_key(type,w) }
      if words.length > 1
        temp_store_key = "tmpsunionstore:#{words.join("+")}"   
        if !Redis::Search.config.redis.exists(temp_store_key)
          # 将多个词语组合对比，得到并集，并存入临时区域   
          Redis::Search.config.redis.sunionstore(temp_store_key,*words)
          # 将临时搜索设为1天后自动清除
          Redis::Search.config.redis.expire(temp_store_key,86400)
        end
        # 根据需要的数量取出 ids
        ids = Redis::Search.config.redis.sort(temp_store_key,:limit => [0,limit])
      else
        ids = Redis::Search.config.redis.sort(words.first,:limit => [0,limit])
      end
      return [] if ids.blank?
      hmget(type,ids)
    end

    # Search items, this will split words by Libmmseg
    # 
    # h3. params:
    #   type      model name
    #   text         search text
    #   :limit    result limit
    # h3. usage:
    # * Redis::Search.query("Tag","Ruby vs Python")
    def self.query(type, text,options = {})
      result = []
      return result if text.strip.blank?

      words = Search.split(text)
      limit = options[:limit] || 10
      sort_field = options[:sort_field] || "id"
      words = words.collect { |w| Search.mk_sets_key(type,w) }
      return result if words.blank?
      temp_store_key = "tmpinterstore:#{words.join("+")}"
      if words.length > 1
        if !Redis::Search.config.redis.exists(temp_store_key)
          # 将多个词语组合对比，得到交集，并存入临时区域
          Redis::Search.config.redis.sinterstore(temp_store_key,*words)
          # 将临时搜索设为1天后自动清除
          Redis::Search.config.redis.expire(temp_store_key,86400)
        end
        # 根据需要的数量取出 ids
        ids = Redis::Search.config.redis.sort(temp_store_key,:limit => [0,limit])
      else
        # 根据需要的数量取出 ids
        ids = Redis::Search.config.redis.sort(words.first,:limit => [0,limit])
      end
      hmget(type,ids, :sort_field => sort_field)
    end
  
    private
      def self.hmget(type, ids, options = {})
        result = []
        sort_field = options[:sort_field] || "id"
        return result if ids.blank?
        Redis::Search.config.redis.hmget(type,*ids).each do |r|
          begin
            result << JSON.parse(r)
          rescue => e
            Search.warn("Search.query failed: #{e}")
          end
        end
        result
      end
  end
end
