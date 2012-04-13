# coding: utf-8
require "spec_helper"

describe "Redis::Search indexing" do
  before do
    @user = User.create(:email => "zsf@gmail.com", :name => "张三丰", :score => 100, :password => "123456")
  end
  
  after do
    User.destroy_all
  end
  
  describe "Creating" do
    it "dose can append index to Redis when use create method" do
      user1 = User.create(:email => "foo@bar.com", :name => "Foo Bar", :score => 10)
      Redis::Search.complete("User","Fo").count.should == 1
      Redis::Search.complete("User","Foo").count.should == 1
      Redis::Search.complete("User","Foo Bar")[0]['id'].should == user1.id.to_s
    end
    
    it "does can append index to Redis when new and save" do
      user2 = User.new(:email => "dhh@gmail.com", :name => "David Heinemeier Hansson", :score => 10)
      user2.save
      Redis::Search.complete("User","David Heinemeier Hansson").count.should == 1
      Redis::Search.complete("User","D").count.should == 1
      Redis::Search.complete("User","Davi").count.should == 1
      Redis::Search.complete("User","David Heinemeier Hansson")[0]['id'].should == user2.id.to_s
      user2.name = "HHD"
      user2.save
      Redis::Search.complete("User","D").count.should == 0
      Redis::Search.complete("User","h").count.should == 1
      Redis::Search.complete("User","hh").count.should == 1
    end
  end
  
  describe "Updating" do
    it "does can reindex when data changed by save" do
      Redis::Search.complete("User","张三丰").count.should == 1
      @user.name = "王八蛋"
      @user.name_was.should == "张三丰"
      @user.save
      Redis::Search.complete("User","张").count.should == 0
      Redis::Search.complete("User","张三丰").count.should == 0
      Redis::Search.complete("User","王八蛋").count.should == 1
    end
    
    it "does can reindex when data changed by update_attributes" do
      Redis::Search.complete("User","张三丰").count.should == 1      
      @user.update_attributes(:name => "张无忌")
      Redis::Search.complete("User","张三丰").count.should == 0
      Redis::Search.complete("User","张无忌").count.should == 1
    end
    
    it "does can reindex when data changed by update_attribute" do
      Redis::Search.complete("User","张三丰").count.should == 1
      @user.update_attribute(:name,"张无忌")
      Redis::Search.complete("User","张三丰").count.should == 0
      Redis::Search.complete("User","张无忌").count.should == 1
    end
  end
  
  describe "Deleting" do
    it "will remove index when deleted by @instance.destroy" do
      Redis::Search.complete("User","张三丰").count.should == 1
      @user.destroy
      Redis::Search.complete("User","张三丰").count.should == 0
    end
    
    it "will remove index when deleted by Model.destroy_all" do
      Redis::Search.complete("User","张三丰").count.should == 1
      User.destroy_all
      Redis::Search.complete("User","张三丰").count.should == 0
    end
    
    it "will remove index when deleted by Model.destroy_all with conditions" do
      Redis::Search.complete("User","张三丰").count.should == 1
      User.destroy_all(:conditions => { '_id' => @user.id})
      Redis::Search.complete("User","张三丰").count.should == 0
    end
  end
end