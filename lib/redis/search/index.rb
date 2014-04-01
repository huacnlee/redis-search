class Redis
  module Search
    class Index
      attr_accessor :type, :title, :id,:score, :aliases, :exts, :condition_fields, :prefix_index_enable
      
      class << self
        def redis
          Redis::Search.config.redis
        end
        
        def remove(options = {})
          type = options[:type]
          self.redis.hdel(type,options[:id])
          self.redis.del(Search.mk_score_key(type,options[:id]))

          words = Search::Index.split_words_for_index(options[:title])
          words.each do |word|
            self.redis.srem(Search.mk_sets_key(type,word), options[:id])
          end

          # remove set for prefix index key
          self.redis.srem(Search.mk_sets_key(type,options[:title]),options[:id])
        end
        
        def split_words_for_index(title)
          words = Search.split(title)
          if Search.config.pinyin_match
            # covert Chinese to pinyin to as an index
            pinyin_full = Search.split_pinyin(title)
            pinyin_first = pinyin_full.collect { |p| p[0] }.join("")
            words += pinyin_full
            words << pinyin_first
            pinyin_full = nil
            pinyin_first = nil
          end
          words.uniq
        end
      end # end class << self
      
      def redis
        self.class.redis
      end
      
      def initialize(options = {})
        # default data
        self.condition_fields = []
        self.exts = []
        self.aliases = []
        self.prefix_index_enable = false

        # set attributes value from params
        options.keys.each do |k|
          self.send("#{k}=", options[k])
        end
        self.aliases << self.title
        self.aliases.uniq!
      end

      def save
        return if self.title.blank?
        data = {:title => self.title, :id => self.id, :type => self.type}
        self.exts.each do |f|
          data[f[0]] = f[1]
        end

        # 将原始数据存入 hashes
        res = self.redis.hset(self.type, self.id, data.to_json)

        # 将目前的编号保存到条件(conditions)字段所创立的索引上面
        self.condition_fields.each do |field|
          self.redis.sadd(Search.mk_condition_key(self.type,field,data[field.to_sym]), self.id)
        end

        # score for search sort
        self.redis.set(Search.mk_score_key(self.type,self.id),self.score)

        # 保存 sets 索引，以分词的单词为key，用于后面搜索，里面存储 ids
        self.aliases.each do |val|
          words = Search::Index.split_words_for_index(val)
          return if words.blank?
          words.each do |word|
            self.redis.sadd(Search.mk_sets_key(self.type,word), self.id)
          end
        end

        # 建立前缀索引
        save_prefix_index if prefix_index_enable
      end

      private
      def save_prefix_index
        self.aliases.each do |val|
          words = []
          words << val.downcase
          self.redis.sadd(Search.mk_sets_key(self.type,val), self.id)
          if Search.config.pinyin_match
            pinyin_full = Search.split_pinyin(val.downcase)
            pinyin_first = pinyin_full.collect { |p| p[0] }.join("")
            pinyin = pinyin_full.join("")
            words << pinyin
            words << pinyin_first
            self.redis.sadd(Search.mk_sets_key(self.type,pinyin), self.id)
            pinyin_full = nil
            pinyin_first = nil
            pinyin = nil
          end

          words.each do |word|
            key = Search.mk_complete_key(self.type)
            (1..(word.length)).each do |l|
              prefix = word[0...l]
              self.redis.zadd(key, 0, prefix)
            end
            self.redis.zadd(key, 0, word + "*")
          end
        end
      end
    end # end Index
  end
end
