class Post < ActiveRecord::Base
  include Redis::Search

  serialize :alias, Array

  belongs_to :user
  belongs_to :category

  redis_search title_field: :title,
               score_field: :hits,
               condition_fields: [:category_id, :user_id],
               ext_fields: [:category_name, :user_name]

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

  redis_search title_field: :name,
               alias_field: :alias,
               score_field: :score,
               condition_fields: [:gender],
               ext_fields: [:email]
end

class Category < ActiveRecord::Base
  include Redis::Search

  redis_search title_field: :name, ext_fields: []
end

class Admin < User
end

class Company < ActiveRecord::Base
  include Redis::Search

  redis_search title_field: :name,
               class_name: 'Company'
end

class Firm < Company
end
