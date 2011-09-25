class Redis
  module Search
    class Index
      attr_accessor :type, :title, :id,:score, :exts, :prefix_index_enable
      def initialize(options = {})
        self.exts = []
        options.keys.each do |k|
          eval("self.#{k} = options[k]")
        end
      end
      
      def save
        return if self.title.blank?
        data = {:title => self.title, :id => self.id, :type => self.type}
        self.exts.each do |f|
          data[f[0]] = f[1]
        end

        # 将原始数据存入 hashes
        res = Redis::Search.config.redis.hset(self.type, self.id, data.to_json)
        # 保存 sets 索引，以分词的单词为key，用于后面搜索，里面存储 ids
        words = Search.split(self.title)
        return if words.blank?
        words.each do |word|
          key = Search.mk_sets_key(self.type,word)
          Redis::Search.config.redis.sadd(key, self.id)
          Redis::Search.config.redis.set(Search.mk_score_key(self.type,self.id),self.score)
        end

        # 建立前最索引
        if prefix_index_enable
          save_prefix_index
        end
      end

      def save_prefix_index
        word = self.title.downcase
        Redis::Search.config.redis.sadd(Search.mk_sets_key(self.type,self.title), self.id)
        key = Search.mk_complete_key(self.type)
        (1..(word.length)).each do |l|
          prefix = word[0...l]
          Redis::Search.config.redis.zadd(key, 0, prefix)
        end
        Redis::Search.config.redis.zadd(key, 0, word + "*")
      end
      
      def self.remove(options = {})
        type = options[:type]
        Redis::Search.config.redis.hdel(type,options[:id])
        words = Search.split(options[:title])
        words.each do |word|
          key = Search.mk_sets_key(type,word)
          Redis::Search.config.redis.srem(key, options[:id])
          Redis::Search.config.redis.del(Search.mk_score_key(self.type,self.id))
        end
      end
    end
  end
end
