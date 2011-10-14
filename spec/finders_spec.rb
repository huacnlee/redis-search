# coding: utf-8
require "spec_helper"

describe "Redis::Search Finders" do
  before :all do
    @user1 = User.create(:email => "zsf@gmail.com", :name => "张三丰", :score => 100, :password => "123456")
    @user2 = User.create(:email => "liubei@gmail.com", :name => "刘备", :score => 200, :password => "abcd")
    @user3 = User.create(:email => "lizhicheng@gmail.com", :name => "李自成", :score => 20, :password => "dsad")
    @user4 = User.create(:email => "zhangwuji@gmail.com", :name => "张无忌", :score => 2000, :password => "123456762")
  end
  
  after :all do
    Post.destroy_all
    User.destroy_all
    Category.destroy_all
  end
  
  describe "init data should fine" do
    it "does there have 4 users" do
      User.count.should == 4
    end
  end
  
  describe "[Complete] method" do
    it "does Chinese can complete with prefix" do
      Redis::Search.complete("User","z").count.should == 2
      Redis::Search.complete("User","z")[0]['title'].should == "张无忌"
    end
  end
end