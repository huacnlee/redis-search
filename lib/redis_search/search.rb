# coding: utf-8
require "rmmseg"
module RedisSearch  
  class Search
    attr_accessor :type, :title, :id, :exts, :prefix_index_enable
    def initialize(options = {})
      self.exts = []
      options.keys.each do |k|
        eval("self.#{k} = options[k]")
      end
    end
  
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
      puts "[RedisSearch][warn]: #{msg}"
    end
  
    # 生成 uuid，用于作为 hashes 的 field, sets 关键词的值
    def self.mk_sets_key(type, key)
      "#{type}:#{key.downcase}"
    end
  
    def self.mk_complete_key(type)
      "Compl#{type}"
    end
  
    def self.word?(word)
      return !/^[\w\u4e00-\u9fa5]+$/i.match(word.force_encoding("UTF-8")).blank?
    end

    def save
      return if self.title.blank?
      data = {:title => self.title, :id => self.id, :type => self.type}
      self.exts.each do |f|
        data[f[0]] = f[1]
      end
    
      # 将原始数据存入 hashes
      res = RedisSearch.config.redis.hset(self.type, self.id, data.to_json)
      # 保存 sets 索引，以分词的单词为key，用于后面搜索，里面存储 ids
      words = Search.split(self.title)
      return if words.blank?
      words.each do |word|
        next if not Search.word?(word)
        key = Search.mk_sets_key(self.type,word)
        RedisSearch.config.redis.sadd(key, self.id)
      end
      
      # 建立前最索引
      if prefix_index_enable
        save_prefix_index
      end
    end
  
    def save_prefix_index
      return if not Search.word?(self.title)
      word = self.title.downcase
      RedisSearch.config.redis.sadd(Search.mk_sets_key(self.type,self.title), self.id)
      key = Search.mk_complete_key(self.type)
      (1..(word.length)).each do |l|
        prefix = word[0...l]
        RedisSearch.config.redis.zadd(key, 0, prefix)
      end
      RedisSearch.config.redis.zadd(key, 0, word + "*")
    end

    def self.remove(options = {})
      puts options.inspect
      type = options[:type]
      RedisSearch.config.redis.hdel(type,options[:id])
      words = Search.split(options[:title])
      words.each do |word|
        next if not Search.word?(word)
        key = Search.mk_sets_key(type,word)
        RedisSearch.config.redis.srem(key, options[:id])
      end
    end

    # Use for short title search, this method is search by chars, for example Tag, User, Category ...
    # 
    # h3. params:
    #   type      model name
    #   w         search char
    #   :limit    result limit
    # h3. usage:
    # * RedisSearch::Search.complete("Tag","r") => ["Ruby","Rails", "REST", "Redis", "Redmine"]
    # * RedisSearch::Search.complete("Tag","re") => ["Redis", "Redmine"]
    # * RedisSearch::Search.complete("Tag","red") => ["Redis", "Redmine"]
    # * RedisSearch::Search.complete("Tag","redi") => ["Redis"]
    def self.complete(type, w, options = {})
      limit = options[:limit] || 10 

      prefix_matchs = []
      # This is not random, try to get replies < MTU size
      rangelen = RedisSearch.config.complete_max_length
      prefix = w.downcase
      key = Search.mk_complete_key(type)
      
      start = RedisSearch.config.redis.zrank(key,prefix)
      return [] if !start
      count = limit
      max_range = start+(rangelen*limit)-1
      range = RedisSearch.config.redis.zrange(key,start,max_range)
      while prefix_matchs.length <= count
        start += rangelen
        break if !range or range.length == 0
        range.each {|entry|
          minlen = [entry.length,prefix.length].min
          if entry[0...minlen] != prefix[0...minlen]
            count = prefix_matchs.count
            break
          end
          # puts entry
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
        if !RedisSearch.config.redis.exists(temp_store_key)
          # 将多个词语组合对比，得到并集，并存入临时区域   
          RedisSearch.config.redis.sunionstore(temp_store_key,*words)
          # 将临时搜索设为1天后自动清除
          RedisSearch.config.redis.expire(temp_store_key,86400)
        end
        # 根据需要的数量取出 ids
        ids = RedisSearch.config.redis.sort(temp_store_key,:limit => [0,limit])
      else
        ids = RedisSearch.config.redis.sort(words.first,:limit => [0,limit])
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
    # * RedisSearch::Search.query("Tag","Ruby vs Python")
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
        if !RedisSearch.config.redis.exists(temp_store_key)
          # 将多个词语组合对比，得到交集，并存入临时区域
          RedisSearch.config.redis.sinterstore(temp_store_key,*words)
          # 将临时搜索设为1天后自动清除
          RedisSearch.config.redis.expire(temp_store_key,86400)
        end
        # 根据需要的数量取出 ids
        ids = RedisSearch.config.redis.sort(temp_store_key,:limit => [0,limit])
      else
        # 根据需要的数量取出 ids
        ids = RedisSearch.config.redis.sort(words.first,:limit => [0,limit])
      end
      hmget(type,ids, :sort_field => sort_field)
    end
  
    private
      def self.hmget(type, ids, options = {})
        result = []
        sort_field = options[:sort_field] || "id"
        return result if ids.blank?
        RedisSearch.config.redis.hmget(type,*ids).each do |r|
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
