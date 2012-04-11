# coding: utf-8
require "spec_helper"

describe "Redis::Search Finders" do
  before :all do
    @user1 = User.create(:email => "zsf@gmail.com", :sex => 1, :name => "张三丰", :alias => ["张三疯","张麻子"], :score => 100, :password => "123456")
    @user2 = User.create(:email => "liubei@gmail.com", :sex => 2, :name => "刘备", :score => 200, :password => "abcd")
    @user3 = User.create(:email => "zicheng.lhs@taobao.com", :sex => 1, :name => "李自成", :score => 20, :password => "dsad")
    @user4 = User.create(:email => "zhang-wuji@me.com", :sex => 1, :name => "张无忌", :score => 2000, :password => "123456762")
    @user5 = User.create(:email => "liao.zhang@apple.com", :sex => 0, :name => "张辽", :score => 700, :password => "abcdks")
    @user6 = User.create(:email => "leo-cheng@gmail.com", :sex => 2, :name => "Leo Peter Cheng", :score => 3, :password => "kdhs")
    
    @category1 = Category.create(:name => "Programming")
    @category2 = Category.create(:name => "My live")
    
    @post1 = Post.create(:user => @user1, 
                          :category => @category1,
                          :title => "How do I check If a Class already exists in Ruby",
                          :hits => 32182)
    @post2 = Post.create(:user => @user3, 
                          :category => @category2,
                          :title => "新版本上线，采用 Twitter 的 Bootstrap 来设计布局",
                          :hits => 100)
    @post3 = Post.create(:user => @user3, 
                          :category => @category1,
                          :title => "redis-search 高效的 Ruby 搜索插件介绍",
                          :hits => 2000)
    @post4 = Post.create(:user => @user2, 
                          :category => @category1,
                          :title => "What different of Ruby Class and Module?",
                          :hits => 6721)
    @post5 = Post.create(:user => @user5, 
                          :category => @category1,
                          :title => "Redis is a right store way for Ruby on Rails project?",
                          :hits => 762)
  end
  
  after :all do
    Post.destroy_all
    User.destroy_all
    Category.destroy_all
  end
  
  describe "init data should be fine" do
    it "does users create fine" do
      User.count.should == 6
    end
    
    it "does categories create fine" do
      Category.count.should == 2
    end
    
    it "does posts create fine" do
      Post.count.should == 5
    end
  end
  
  describe "[Complete] method" do
    it "does Chinese can complete with prefix" do
      items = Redis::Search.complete("User","张")
      items.count.should == 3
      
      Redis::Search.complete("User","张三").count.should == 1
      Redis::Search.complete("User","张三丰").count.should == 1
    end
    
    it "should search with alias" do
      Redis::Search.complete("User","张三疯").count.should == 1
      Redis::Search.complete("User","张麻").count.should == 1
      Redis::Search.complete("User","张麻子").count.should == 1
    end
    
    it "does Pinyin can complete with prefix" do
      items = Redis::Search.complete("User","z")
      items.count.should == 3

      Redis::Search.complete("User","zhangs").count.should == 1
      Redis::Search.complete("User","zhangl").count.should == 1
      Redis::Search.complete("User","zhangn").count.should == 0
      Redis::Search.complete("User","zh").count.should == 3
      Redis::Search.complete("User","zha").count.should == 3
      Redis::Search.complete("User","zhan").count.should == 3
      Redis::Search.complete("User","zhangw").count.should == 1
      Redis::Search.complete("User","zhangw")[0]['id'].should == @user4.id.to_s
    end
    
    it "does can return defined attributes" do
      Redis::Search.complete("User","张三")[0].keys.should == ["title", "id", "type", "email", "score", "sex"]
    end
    
    it "does can return right attribute values" do
      item = Redis::Search.complete("User","张三")[0]
      item['id'].should == @user1.id.to_s
      item['title'].should == @user1.name
      item['email'].should == @user1.email
      item['score'].should == @user1.score
    end
    
    it "does can return right order" do
      items = Redis::Search.complete("User","z")
      items[0]['id'].should == @user4.id.to_s
      items[1]['id'].should == @user5.id.to_s
      items[2]['id'].should == @user1.id.to_s
    end
    
    it "does support English" do
      items = Redis::Search.complete("User","l")
      items.count.should == 3
      items[0]['id'].should == @user2.id.to_s
      items[1]['id'].should == @user3.id.to_s
      items[2]['id'].should == @user6.id.to_s
    end
    
    it "does will return [] when search key is null or found no result" do
      Redis::Search.complete("User","").should == []
      Redis::Search.complete("User",nil).should == []
      Redis::Search.complete("",nil).should == []
      Redis::Search.complete("User","adslgkjaslkdgjalksdgj").should == []
    end
    
    it "does search with conditions" do
      Redis::Search.complete("User", "l", :conditions => [:sex => 2]).count.should == 2
      Redis::Search.complete("User", "li", :conditions => [:sex => 2]).count.should == 1
    end
    
    it "does search only by conditions" do
      Redis::Search.complete("User", "", :conditions => [:sex => 1]).count.should == 3
      Redis::Search.complete("User", "", :conditions => [:sex => 2]).count.should == 2
      Redis::Search.complete("User", "", :conditions => [:sex => 0]).count.should == 1
    end
  end
  
  describe "[Query] method" do
    it "does search with different word combinations" do
      Redis::Search.query("Post", "Ruby").count.should == 4
      Redis::Search.query("Post", "Ruby on Rails")[0]['title'].should == @post5.title
      Redis::Search.query("Post", "Rails Ruby")[0]['title'].should == @post5.title
    end
    
    it "does search with different Chinese word combinations" do
      Redis::Search.query("Post", "介绍搜索插件").count.should == 1
      Redis::Search.query("Post", "介绍搜索插件")[0]['title'].should == @post3.title
      Redis::Search.query("Post", "介绍插件搜索")[0]['title'].should == @post3.title
      Redis::Search.query("Post", "搜索介绍插件")[0]['title'].should == @post3.title
      Redis::Search.query("Post", "搜索redis-search介绍插件")[0]['title'].should == @post3.title
      Redis::Search.query("Post", "search介绍插件")[0]['title'].should == @post3.title
      Redis::Search.query("Post", "Twitter Bootstrap 设计")[0]['title'].should == @post2.title
      Redis::Search.query("Post", "Twitter 设计 Bootstrap")[0]['title'].should == @post2.title
      Redis::Search.query("Post", "Twitter设计Bootstrap")[0]['title'].should == @post2.title
    end
    
    it "does search Ext field existed." do
      Redis::Search.query("Post", "How do")[0]['category_name'] == @category1.name
      Redis::Search.query("Post", "How do")[0]['user_name'] == @user1.name
    end
    
    it "does search with Pinyin" do
      Redis::Search.query("Post", "jie shao 搜索")[0]['title'].should == @post3.title
      Redis::Search.query("Post", "redis搜索jie shao")[0]['title'].should == @post3.title
      Redis::Search.query("Post", "ruby 插件搜索redis jie shao")[0]['title'].should == @post3.title
      Redis::Search.query("Post", "jie")[0]['title'].should == @post3.title
    end
    
    it "does search with a conditions" do
      Redis::Search.query("Post", "Ruby", :conditions => [:user_id => @user3.id]).count.should == 1
      Redis::Search.query("Post", "Ruby on Rails", :conditions => [:user_id => @user3.id]).count.should == 0
    end
    
    it "does search with more conditions" do
      Redis::Search.query("Post", "", :conditions => [:user_id => @user3.id, :category_id => @category1.id]).count.should == 1
      Redis::Search.query("Post", "Ruby", :conditions => [:user_id => @user3.id, :category_id => @category1.id]).count.should == 1
      Redis::Search.query("Post", "Ruby", :conditions => [:user_id => @user3.id, :category_id => @category2.id]).count.should == 0
    end
    
    it "does search only by conditions" do
      Redis::Search.query("Post", "", :conditions => [:user_id => @user3.id]).count.should == 2
      Redis::Search.query("Post", "", :conditions => [:category_id => @category2.id]).count.should == 1
    end
  end
  
  describe "Segment words" do
    it "does split words method can work fine." do
      Redis::Search.split("Ruby on Rails").should == ["Ruby","on","Rails"]
      Redis::Search.split("如何掌控自己的学习和生活").collect { |t| t.force_encoding("utf-8") }.should == (["如何", "掌", "控", "自己的", "学习", "和", "生活"])
    end
  end
end