# coding: utf-8
require "spec_helper"

describe "subject" do
  after(:all) do
    User.destroy_all
  end
  
  it "does something" do
    @user = User.create(:email => "zsf@gmail.com", :name => "称丰田", :alias => ["纹力神","王尔马"], :score => 100, :password => "123456")
    Redis::Search.complete("User","称").count.should == 1
    Redis::Search.complete("User","纹").count.should == 1
    Redis::Search.complete("User","王尔").count.should == 1
    @user.name = "李白"
    @user.alias = ["纹力神","成大家"]
    @user.alias_was.should == ["纹力神","王尔马"]
    @user.save
    Redis::Search.complete("User","称").count.should == 0
    Redis::Search.complete("User","李").count.should == 1
    Redis::Search.complete("User","王").count.should == 0
    Redis::Search.complete("User","成").count.should == 1
    Redis::Search.complete("User","纹").count.should == 1
  end
end