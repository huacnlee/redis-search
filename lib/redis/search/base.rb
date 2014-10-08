# coding: utf-8
class Redis
  module Search
    autoload :PinYin, 'ruby-pinyin'

    extend ::ActiveSupport::Concern

    included do
      cattr_reader :redis_search_options

      before_destroy :redis_search_index_before_destroy
      after_update :redis_search_index_after_update
      after_save :redis_search_index_after_save
    end

    def redis_search_fields_to_hash(ext_fields)
      exts = {}
      ext_fields.each do |f|
        exts[f] = instance_eval(f.to_s)
      end
      exts
    end

    def redis_search_alias_value(field)
      return [] if field.blank? || field == "_was".freeze
      val = (instance_eval("self.#{field}") || "".freeze).clone
      return [] if !val.class.in?([String,Array])
      if val.is_a?(String)
        val = val.to_s.split(",")
      end
      val
    end

    # Rebuild search index with create
    def redis_search_index_create
      s = Search::Index.new(title: self.send(self.redis_search_options[:title_field]),
                            aliases: self.redis_search_alias_value(self.redis_search_options[:alias_field]),
                            id: self.id,
                            exts: self.redis_search_fields_to_hash(self.redis_search_options[:ext_fields]),
                            type: self.redis_search_options[:class_name] || self.class.name,
                            condition_fields: self.redis_search_options[:condition_fields],
                            score: self.send(self.redis_search_options[:score_field]).to_i,
                            prefix_index_enable: self.redis_search_options[:prefix_index_enable])
      s.save
      # release s
      s = nil
      true
    end

    def redis_search_index_delete(titles)
      titles.uniq!
      titles.each do |title|
        next if title.blank?
        Search::Index.remove(id: self.id, title: title, type: self.class.name)
      end
      true
    end

    def redis_search_index_before_destroy
      titles = []
      titles = redis_search_alias_value(self.redis_search_options[:alias_field])
      titles << self.send(self.redis_search_options[:title_field])

      redis_search_index_delete(titles)
      true
    end

    def redis_search_index_need_reindex
      index_fields_changed = false
      self.redis_search_options[:ext_fields].each do |f|
        next if f.to_s == "id".freeze
        field_method = "#{f}_changed?"
        if self.methods.index(field_method.to_sym) == nil
          Redis::Search.warn("#{self.class.name} model reindex on update need #{field_method} method.")
          next
        end

        index_fields_changed = true if instance_eval(field_method)
      end

      begin
        if self.send("#{self.redis_search_options[:title_field]}_changed?")
          index_fields_changed = true
        end

        if self.send(self.redis_search_options[:alias_field]) || self.send("#{self.redis_search_options[:title_field]}_changed?")
          index_fields_changed = true
        end
      rescue
      end

      return index_fields_changed
    end

    def redis_search_index_after_update
      if self.redis_search_index_need_reindex
        titles = []
        titles = redis_search_alias_value("#{self.redis_search_options[:alias_field]}_was")
        titles << self.send("#{self.redis_search_options[:title_field]}_was")
        redis_search_index_delete(titles)
      end

      true
    end

    def redis_search_index_after_save
      if self.redis_search_index_need_reindex || self.new_record?
        self.redis_search_index_create
      end
      true
    end

    module ClassMethods
      # Config redis-search index for Model
      # == Params:
      #   title_field   Query field for Search
      #   alias_field   Alias field for search, can accept multi field (String or Array type) it type is String, redis-search will split by comma
      #   prefix_index_enable   Is use prefix index search
      #   ext_fields    What kind fields do you need inlucde to search indexes
      #   score_field   Give a score for search sort, need Integer value, default is `created_at`
      def redis_search_index(opts = {})
        opts[:title_field] ||= :title
        opts[:alias_field] ||= nil
        opts[:prefix_index_enable] ||= false
        opts[:ext_fields] ||= []
        opts[:score_field] ||= :created_at
        opts[:condition_fields] ||= []
        opts[:class_name] ||= nil

        # Add score field to ext_fields
        opts[:ext_fields] += [opts[:score_field]]

        # Add condition fields to ext_fields
        opts[:ext_fields] += opts[:condition_fields] if opts[:condition_fields].is_a?(Array)

        # store Model name to indexed_models for Rake tasks
        Search.indexed_models = [] if Search.indexed_models == nil
        Search.indexed_models << self

        class_variable_set("@@redis_search_options".freeze, opts)
      end

      def redis_search_index_batch_create(batch_size = 1000, progressbar = false)
        count = 0
        if self.ancestors.collect { |klass| klass.to_s }.include?("ActiveRecord::Base".freeze)
          find_in_batches(:batch_size => batch_size) do |items|
            items.each do |item|
              item.redis_search_index_create
              count += 1
              print "." if progressbar
            end
          end
        elsif self.included_modules.collect { |m| m.to_s }.include?("Mongoid::Document".freeze)
          all.each_slice(batch_size) do |items|
            items.each do |item|
              item.redis_search_index_create
              count += 1
              print "." if progressbar
            end
          end
        else
          puts "skiped, not support this ORM in current."
        end

        count
      end
    end
  end
end
