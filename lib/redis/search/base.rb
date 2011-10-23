# coding: utf-8
class Redis
  module Search
    extend ActiveSupport::Concern

    module ClassMethods
      # Config redis-search index for Model
      # == Params:
      #   title_field   Query field for Search
      #   prefix_index_enable   Is use prefix index search
      #   ext_fields    What kind fields do you need inlucde to search indexes
      #   score_field   Give a score for search sort, need Integer value, default is `created_at`
      def redis_search_index(options = {})
        title_field = options[:title_field] || :title
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

          # after_create :redis_search_index_create
          def redis_search_index_create
            s = Search::Index.new(:title => self.#{title_field}, 
                                  :id => self.id, 
                                  :exts => self.redis_search_fields_to_hash(#{ext_fields.inspect}), 
                                  :type => self.class.to_s,
                                  :condition_fields => #{condition_fields},
                                  :score => self.#{score_field}.to_i,
                                  :prefix_index_enable => #{prefix_index_enable})
            s.save
            # release s
            s = nil
          end

          before_destroy :redis_search_index_destroy
          def redis_search_index_destroy
            Search::Index.remove(:id => self.id, :title => self.#{title_field}, :type => self.class.to_s)
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
              if(self.#{title_field}_changed?)
                index_fields_changed = true
              end
            rescue
            end
            return index_fields_changed
          end
          
          after_update :redis_search_index_remove
          def redis_search_index_remove
            # DEBUG info
            # puts '>>>>>>>>>>>>>>>>>>>>>>' 
            # puts self.redis_search_index_need_reindex
            # puts self.#{title_field}_was
            # puts self.#{title_field}
            if self.redis_search_index_need_reindex
              Search::Index.remove(:id => self.id, :title => self.#{title_field}_was, :type => self.class.to_s)
            end
          end

          after_save :redis_search_index_update
          def redis_search_index_update
            if self.redis_search_index_need_reindex
              self.redis_search_index_create
            end
          end
        )
      end
    end
  end
end