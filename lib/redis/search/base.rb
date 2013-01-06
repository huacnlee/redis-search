# coding: utf-8
class Redis
  module Search
    extend ActiveSupport::Concern

    module ClassMethods
      # Config redis-search index for Model
      # == Params:
      #   title_field   Query field for Search
      #   alias_field   Alias field for search, can accept multi field (String or Array type), it type is String, redis-search will split by comma
      #   prefix_index_enable   Is use prefix index search
      #   ext_fields    What kind fields do you need inlucde to search indexes
      #   score_field   Give a score for search sort, need Integer value, default is `created_at`
      def redis_search_index(options = {})
        title_field = options[:title_field] || :title
        alias_field = options[:alias_field] || nil
        prefix_index_enable = options[:prefix_index_enable] || false
        ext_fields = options[:ext_fields] || []
        score_field = options[:score_field] || :created_at
        condition_fields = options[:condition_fields] || []
        # Add score field to ext_fields
        ext_fields |= [score_field]
        # Add condition fields to ext_fields
        ext_fields |= condition_fields
        
        # store Model name to indexed_models for Rake tasks
        Search.indexed_models = [] if Search.indexed_models == nil
        Search.indexed_models << self
        # bind instance methods and callback events
        class_eval %(
          def redis_search_fields_to_hash(ext_fields)
            exts = {}
            ext_fields.each do |f|
              exts[f] = instance_eval(f.to_s)
            end
            exts
          end
          
          def redis_search_alias_value(field)
            return [] if field.blank? or field == "_was"
            val = instance_eval("self.\#{field}").clone
            return [] if !val.class.in?([String,Array])
            if val.is_a?(String)
              val = val.to_s.split(",")
            end
            val
          end

          def redis_search_index_create
            s = Search::Index.new(:title => self.#{title_field}, 
                                  :aliases => self.redis_search_alias_value(#{alias_field.inspect}), 
                                  :id => self.id, 
                                  :exts => self.redis_search_fields_to_hash(#{ext_fields.inspect}), 
                                  :type => self.class.to_s,
                                  :condition_fields =>#{RUBY_VERSION.start_with?('1.8')? '['+condition_fields.collect{|c| "'#{c}'"}.join(',')+']' : condition_fields},
                                  :score => self.#{score_field}.to_i,
                                  :prefix_index_enable => #{prefix_index_enable})
            s.save
            # release s
            s = nil
            true
          end
          
          def redis_search_index_delete(titles)
            titles.uniq.each do |title|
              Search::Index.remove(:id => self.id, :title => title, :type => self.class.to_s)
            end
            true
          end
          

          before_destroy do
            titles = []
            titles = redis_search_alias_value("#{alias_field}")
            titles << self.#{title_field}
            
            redis_search_index_delete(titles)
            true
          end
          
          
          def redis_search_index_need_reindex
            index_fields_changed = false
            #{ext_fields.inspect}.each do |f|
              next if f.to_s == "id"
              field_method = f.to_s + "_changed?"
              if !self.methods.include?(field_method.to_sym)
                Search.warn("#{self.class.name} model reindex on update need "+field_method+" method.")
                next
              end
              if instance_eval(field_method)
                index_fields_changed = true
              end
            end
            begin
              if self.#{title_field}_changed?
                index_fields_changed = true
              end
              if self.#{alias_field || title_field}_changed?
                index_fields_changed = true
              end
            rescue
            end
            return index_fields_changed
          end
          
          after_update do
            if self.redis_search_index_need_reindex
              titles = []
              titles = redis_search_alias_value("#{alias_field}_was")
              titles << self.#{title_field}_was
              redis_search_index_delete(titles)
            end
            true
          end

          after_save :redis_search_index_update
          def redis_search_index_update
            if self.redis_search_index_need_reindex or self.new_record?
              self.redis_search_index_create
            end
            true
          end
        )
      end
    end
  end
end
