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
      
        # store Model name to indexed_models for Rake tasks
        Search.indexed_models = [] if Search.indexed_models == nil
        Search.indexed_models << self
        # bind instance methods and callback events
        class_eval %(
          def redis_search_ext_fields(ext_fields)
            exts = {}
            ext_fields.each do |f|
              exts[f] = instance_eval(f.to_s)
            end
            exts
          end

          after_create :redis_search_index_create
          def redis_search_index_create
            s = Search::Index.new(:title => self.#{title_field}, 
                           :id => self.id, 
                           :exts => self.redis_search_ext_fields(#{ext_fields.inspect}), 
                           :type => self.class.to_s,
                           :score => self.#{score_field}.to_i,
                           :prefix_index_enable => #{prefix_index_enable})
            s.save
            # release s
            s = nil
          end

          before_destroy :redis_search_index_remove
          def redis_search_index_remove
            Search::Index.remove(:id => self.id, :title => self.#{title_field}, :type => self.class.to_s)
          end

          before_update :redis_search_index_update
          def redis_search_index_update
            index_fields_changed = false
            #{ext_fields.inspect}.each do |f|
              next if f.to_s == "id"
              if instance_eval(f.to_s + "_changed?")
                index_fields_changed = true
              end
            end
            begin
              if(self.#{title_field}_changed?)
                index_fields_changed = true
              end
            rescue
            end
            if index_fields_changed
              Search::Index.remove(:id => self.id, :title => self.#{title_field}_was, :type => self.class.to_s)
              self.redis_search_index_create
            end
          end
        )
      end
    end
  end
end