class Post < ActiveRecord::Base
  include Redis::Search

  serialize :alias, Array

  belongs_to :user
  belongs_to :category

  redis_search_index(title_field: :title,
                     score_field: :hits,
                     condition_fields: [:category_id, :user_id],
                     ext_fields: [:category_name, :user_name])

  def category_name
    category.name unless category.blank?
  end

  def user_name
    user.name unless category.blank?
  end
end

class User < ActiveRecord::Base
  include Redis::Search

  serialize :alias, Array

  has_many :posts

  redis_search_index(title_field: :name,
                     alias_field: :alias,
                     score_field: :score,
                     condition_fields: [:gender],
                     prefix_index_enable: true,
                     ext_fields: [:email])
end

class Category < ActiveRecord::Base
  include Redis::Search

  redis_search_index(title_field: :name,
                     prefix_index_enable: true,
                     ext_fields: [])
end

class Admin < User
end

class Company < ActiveRecord::Base
  include Redis::Search

  redis_search_index(title_field: :name,
                     prefix_index_enable: true,
                     class_name: 'Company')
end

class Firm < Company
end
