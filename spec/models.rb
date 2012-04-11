class Post
  include Mongoid::Document
  include Mongoid::Timestamps
  include Redis::Search

  field :title
  field :alias, :type => Array, :default => []
  field :body
  field :hits

  belongs_to :user
  belongs_to :category

  redis_search_index(:title_field => :title,
                     :score_field => :hits,
                     :condition_fields => [:category_id,:user_id],
                     :ext_fields => [:category_name,:user_name])

  def category_name
    self.category.name if not self.category.blank?
  end
  
  def user_name
    self.user.name if not self.category.blank?
  end
end

class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include Redis::Search
  

  field :email
  field :password
  field :name
  field :alias, :type => Array, :default => []
  field :score
  field :sex, :type => Integer, :default => 0
  
  has_many :posts

  redis_search_index(:title_field => :name,
                     :alias_field => :alias,
                     :score_field => :score,
                     :condition_fields => [:sex],
                     :prefix_index_enable => true,
                     :ext_fields => [:email])
end


class Category
  include Mongoid::Document
  include Mongoid::Timestamps
  include Redis::Search
  

  field :name

  redis_search_index(:title_field => :name,
                     :prefix_index_enable => true,
                     :ext_fields => [])
end