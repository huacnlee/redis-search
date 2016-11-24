# coding: utf-8
class Redis
  module Search
    class << self
      # Use for short title search, this method is search by chars, for example Tag, User, Category ...
      #
      # h3. params:
      #   type      model name
      #   w         search char
      #   :limit    result limit
      #   :order    result order
      #
      # h3. usage:
      #
      # * Redis::Search.complete("Tag","r") => ["Ruby","Rails", "REST", "Redis", "Redmine"]
      # * Redis::Search.complete("Tag","re") => ["Redis", "Redmine"]
      # * Redis::Search.complete("Tag","red") => ["Redis", "Redmine"]
      # * Redis::Search.complete("Tag","redi") => ["Redis"]
      def complete(type, w, options = {})
        limit      = options[:limit] || 10
        conditions = options[:conditions] || []
        order      = options[:order] || 'desc'
        return [] if (w.blank? && conditions.blank?) || type.blank?

        prefix_matchs = []
        # This is not random, try to get replies < MTU size
        rangelen = config.complete_max_length
        prefix = w.downcase
        key = mk_complete_key(type)

        if start = config.redis.zrank(key, prefix)
          count = limit
          max_range = start + (rangelen * limit) - 1
          range = config.redis.zrange(key, start, max_range)
          while prefix_matchs.length <= count
            start += rangelen
            break if !range || range.empty?
            range.each do |entry|
              minlen = [entry.length, prefix.length].min
              if entry[0...minlen] != prefix[0...minlen]
                count = prefix_matchs.count
                break
              end
              if entry[-1..-1] == '*' && prefix_matchs.length != count
                prefix_matchs << entry[0...-1]
              end
            end

            range = range[start..max_range]
          end
        end
        prefix_matchs.uniq!

        # 组合 words 的特别 key 名
        words = prefix_matchs.collect { |w| mk_sets_key(type, w) }

        # 组合特别 key ,但这里不会像 query 那样放入 words， 因为在 complete 里面 words 是用 union 取的，condition_keys 和 words 应该取交集
        condition_keys = []
        unless conditions.blank?
          conditions = conditions[0] if conditions.is_a?(Array)
          conditions.each_key do |c|
            condition_keys << mk_condition_key(type, c, conditions[c])
          end
        end

        # 按词语搜索
        temp_store_key = "tmpsunionstore:#{words.join('+')}"
        if words.length > 1
          unless config.redis.exists(temp_store_key)
            # 将多个词语组合对比，得到并集，并存入临时区域
            config.redis.sunionstore(temp_store_key, *words)
            # 将临时搜索设为1天后自动清除
            config.redis.expire(temp_store_key, 86_400)
          end
          # 根据需要的数量取出 ids
        else
          temp_store_key = words.first
        end

        # 如果有条件，这里再次组合一下
        unless condition_keys.blank?
          condition_keys << temp_store_key unless words.blank?
          temp_store_key = "tmpsinterstore:#{condition_keys.join('+')}"
          unless config.redis.exists(temp_store_key)
            config.redis.sinterstore(temp_store_key, *condition_keys)
            config.redis.expire(temp_store_key, 86_400)
          end
        end

        ids = config.redis.sort(temp_store_key,
                                limit: [0, limit],
                                by: mk_score_key(type, '*'),
                                order: order)
        return [] if ids.blank?
        hmget(type, ids)
      end

      alias_method :query, :complete

    end # end class << self


    private

    def self.warn(msg)
      return unless Redis::Search.config.debug
      msg = "\e[33m[redis-search] #{msg}\e[0m"
      if defined?(Rails) == 'constant' && Rails.class == Class
        ::Rails.logger.warn(msg)
      else
        puts msg
      end
    end

    def self.info(msg)
      return unless Redis::Search.config.debug
      msg = "\e[32m[redis-search] #{msg}\e[0m"
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
      return result if ids.blank?
      config.redis.hmget(type, *ids).each do |r|
        begin
          result << JSON.parse(r) unless r.blank?
        rescue => e
          warn("Search.query failed: #{e}")
        end
      end
      result
    end
  end # end Search
end
