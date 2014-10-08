# coding: utf-8
class Redis
  module Search
    class << self
      # use rmmseg to split words
      def split(text)
        _split(text)
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
      def complete(type, w, options = {})
        limit      = options[:limit] || 10
        conditions = options[:conditions] || []
        return [] if (w.blank? && conditions.blank?) || type.blank?

        prefix_matchs = []
        # This is not random, try to get replies < MTU size
        rangelen = self.config.complete_max_length
        prefix = w.downcase
        key = self.mk_complete_key(type)

        if start = self.config.redis.zrank(key,prefix)
          count = limit
          max_range = start + (rangelen * limit) - 1
          range = self.config.redis.zrange(key,start,max_range)
          while prefix_matchs.length <= count
            start += rangelen
            break if !range || range.length == 0
            range.each do |entry|
              minlen = [entry.length,prefix.length].min
              if entry[0...minlen] != prefix[0...minlen]
                count = prefix_matchs.count
                break
              end
              if entry[-1..-1] == "*" && prefix_matchs.length != count
                prefix_matchs << entry[0...-1]
              end
            end

            range = range[start..max_range]
          end
        end
        prefix_matchs.uniq!

        # 组合 words 的特别 key 名
        words = prefix_matchs.collect { |w| self.mk_sets_key(type,w) }

        # 组合特别 key ,但这里不会像 query 那样放入 words， 因为在 complete 里面 words 是用 union 取的，condition_keys 和 words 应该取交集
        condition_keys = []
        if !conditions.blank?
          conditions = conditions[0] if conditions.is_a?(Array)
          conditions.keys.each do |c|
            condition_keys << self.mk_condition_key(type,c,conditions[c])
          end
        end

        # 按词语搜索
        temp_store_key = "tmpsunionstore:#{words.join("+")}"
        if words.length > 1
          if !self.config.redis.exists(temp_store_key)
            # 将多个词语组合对比，得到并集，并存入临时区域
            self.config.redis.sunionstore(temp_store_key,*words)
            # 将临时搜索设为1天后自动清除
            self.config.redis.expire(temp_store_key,86400)
          end
          # 根据需要的数量取出 ids
        else
          temp_store_key = words.first
        end

        # 如果有条件，这里再次组合一下
        if !condition_keys.blank?
          condition_keys << temp_store_key if !words.blank?
          temp_store_key = "tmpsinterstore:#{condition_keys.join('+')}"
          if !self.config.redis.exists(temp_store_key)
            self.config.redis.sinterstore(temp_store_key,*condition_keys)
            self.config.redis.expire(temp_store_key,86400)
          end
        end

        ids = self.config.redis.sort(temp_store_key,
                                     limit: [0,limit],
                                     by: self.mk_score_key(type,"*"),
                                     order: "desc")
        return [] if ids.blank?
        self.hmget(type,ids)
      end

      # Search items, this will split words by Libmmseg
      #
      # h3. params:
      #   type      model name
      #   text         search text
      #   :limit    result limit
      # h3. usage:
      # * Redis::Search.query("Tag","Ruby vs Python")
      def query(type, text, options = {})
        tm         = Time.now
        result     = []
        limit      = options[:limit] || 10
        sort_field = options[:sort_field] || "id"
        conditions = options[:conditions] || []

        # 如果搜索文本和查询条件均没有，那就直接返回 []
        return result if text.strip.blank? && conditions.blank?

        words = self.split(text)
        words = words.collect { |w| self.mk_sets_key(type,w) }

        condition_keys = []
        if !conditions.blank?
          conditions = conditions[0] if conditions.is_a?(Array)
          conditions.keys.each do |c|
            condition_keys << self.mk_condition_key(type,c,conditions[c])
          end
          # 将条件的 key 放入关键词搜索集合内，用于 sinterstore 搜索
          words += condition_keys
        end

        return result if words.blank?

        temp_store_key = "tmpinterstore:#{words.join("+")}"

        if words.length > 1
          if !self.config.redis.exists(temp_store_key)
            self.config.redis.pipelined do
              # 将多个词语组合对比，得到交集，并存入临时区域
              self.config.redis.sinterstore(temp_store_key,*words)
              # 将临时搜索设为1天后自动清除
              self.config.redis.expire(temp_store_key,86400)

              # 拼音搜索
              if self.config.pinyin_match
                pinyin_words = self.split_pinyin(text)
                pinyin_words = pinyin_words.collect { |w| self.mk_sets_key(type,w) }
                pinyin_words += condition_keys
                temp_sunion_key = "tmpsunionstore:#{words.join("+")}"
                temp_pinyin_store_key = "tmpinterstore:#{pinyin_words.join("+")}"
                # 找出拼音的
                self.config.redis.sinterstore(temp_pinyin_store_key,*pinyin_words)
                # 合并中文和拼音的搜索结果
                self.config.redis.sunionstore(temp_sunion_key,*[temp_store_key,temp_pinyin_store_key])
                # 将临时搜索设为1天后自动清除
                self.config.redis.expire(temp_pinyin_store_key,86400)
                self.config.redis.expire(temp_sunion_key,86400)
              end
              temp_store_key = temp_sunion_key
            end
          end
        else
          temp_store_key = words.first
        end

        # 根据需要的数量取出 ids
        ids = self.config.redis.sort(temp_store_key,
                                     limit: [0,limit],
                                     by: self.mk_score_key(type,"*"),
                                     order: "desc")
        result = self.hmget(type, ids, sort_field: sort_field)
        self.info("{#{type} : \"#{text}\"} | Time spend: #{Time.now - tm}s")
        result
      end
    end # end class << self

    protected
    def self.split_pinyin(text)
      # Pinyin search split as pinyin again
      _split(PinYin.sentence(text))
    end

    private
    def self._split(text)
      return [] if text.blank?
      # return chars if disabled rmmseg
      return text.split("") if Search.config.disable_rmmseg

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
      return if not Redis::Search.config.debug
      msg = "\e[33m[Redis::Search] #{msg}\e[0m"
      if defined?(Rails) == 'constant' && Rails.class == Class
        ::Rails.logger.warn(msg)
      else
        puts msg
      end
    end

    def self.info(msg)
      return if not Redis::Search.config.debug
      msg = "\e[32m[Redis::Search] #{msg}\e[0m"
      if defined?(Rails) == 'constant' && Rails.class == Class
        ::Rails.logger.debug(msg)
      else
        puts msg
      end
    end

    # 生成 uuid，用于作为 hashes 的 field, sets 关键词的值
    def self.mk_sets_key(type, key)
      "#{type}:#{key.downcase}"
    end

    def self.mk_score_key(type, id)
      "#{type}:_score_:#{id}"
    end

    def self.mk_condition_key(type, field, id)
      "#{type}:_by:_#{field}:#{id}"
    end

    def self.mk_complete_key(type)
      "Compl#{type}"
    end

    def self.hmget(type, ids, options = {})
      result = []
      sort_field = options[:sort_field] || "id"
      return result if ids.blank?
      self.config.redis.hmget(type,*ids).each do |r|
        begin
          result << JSON.parse(r) if !r.blank?
        rescue => e
          self.warn("Search.query failed: #{e}")
        end
      end
      result
    end
  end # end Search
end
