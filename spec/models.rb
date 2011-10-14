class Post
  include Mongoid::Document
  include Mongoid::Timestamps
  include Redis::Search

  field :title
  field :body
  field :hits

  belongs_to :user
  belongs_to :category

  redis_search_index(:title_field => :title,
                     :score_field => :hits,
                     :ext_fields => [:category_name,:user_name])

  def category_name
    self.category.name
  end
  
  def user_name
    self.user.name
  end
end

class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include Redis::Search
  

  field :email
  field :password
  field :name
  field :score
  
  has_many :posts

  redis_search_index(:title_field => :name,
                     :score_field => :score,
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
                     :ext_fields => [:category_name])

  def category_name
    self.category.name
  end
end