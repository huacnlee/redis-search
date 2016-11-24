# coding: utf-8
class Redis
  module Search
    class Index
      attr_accessor :type, :title, :id, :score, :aliases, :exts,
                    :condition_fields

      class << self
        def redis
          Redis::Search.config.redis
        end

        def remove(options = {})
          type = options[:type]

          redis.pipelined do
            redis.hdel(type, options[:id])
            redis.del(Search.mk_score_key(type, options[:id]))

            words = split_words_for_index(options[:title])
            words.each do |word|
              redis.srem(Search.mk_sets_key(type, word), options[:id])
            end

            # remove set for prefix index key
            redis.srem(Search.mk_sets_key(type, options[:title]), options[:id])
          end
        end

        def bm
          t1 = Time.now
          yield
          t2 = Time.now
          puts "spend (#{t2 - t1}s)"
        end
      end # end class << self

      def redis
        self.class.redis
      end

      def initialize(options = {})
        # default data
        @condition_fields    = []
        @exts                = []
        @aliases             = []

        # set attributes value from params
        options.each_key do |k|
          send("#{k}=", options[k])
        end
        @aliases << title
        @aliases.uniq!
      end

      def save
        return if @title.blank?

        redis.pipelined do
          data = { title: @title, id: @id, type: @type }
          exts.each do |f|
            data[f[0]] = f[1]
          end

          # 将原始数据存入 hashes
          res = redis.hset(@type, @id, data.to_json)

          # 将目前的编号保存到条件(conditions)字段所创立的索引上面
          condition_fields.each do |field|
            redis.sadd(Search.mk_condition_key(@type, field, data[field.to_sym]), @id)
          end

          # score for search sort
          redis.set(Search.mk_score_key(@type, @id), @score)

          # 保存 sets 索引，以分词的单词为key，用于后面搜索，里面存储 ids
          aliases.each do |val|
            words = Search::Index.split_words_for_index(val)
            next if words.blank?
            words.each do |word|
              redis.sadd(Search.mk_sets_key(@type, word), @id)
            end
          end

          # 建立前缀索引
          save_prefix_index
        end
      end

      private

      def save_prefix_index
        sorted_set_key = Search.mk_complete_key(@type)
        sorted_vals = []

        aliases.each do |val|
          words = []
          words << val.downcase

          redis.sadd(Search.mk_sets_key(@type, val), @id)

          if Search.config.pinyin_match
            pinyin_full = self.class.split_pinyin(val.downcase)
            pinyin_first = pinyin_full.collect { |p| p[0] }.join('')
            pinyin = pinyin_full.join('')

            words << pinyin
            words << pinyin_first

            redis.sadd(Search.mk_sets_key(@type, pinyin), @id)
          end

          words.each do |word|
            (1..(word.length)).each do |l|
              prefix = word[0...l]
              sorted_vals << [0, prefix]
            end
            sorted_vals << [0, "#{word}*"]
          end
        end

        redis.zadd(sorted_set_key, sorted_vals)
      end

      def self.split_words_for_index(title)
        words = title.split('')
        if Search.config.pinyin_match
          # covert Chinese to pinyin to as an index
          pinyin_full = split_pinyin(title)
          pinyin_first = pinyin_full.collect { |p| p[0] }.join('')
          words += pinyin_full
          words << pinyin_first
        end
        words.uniq
      end

      def self.split_pinyin(text)
        # Pinyin search split as pinyin again
        pinyin = PinYin.sentence(text)
        pinyin.split(' ')
      end

    end # end Index
  end
end
