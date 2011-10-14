# coding: utf-8
require "spec_helper"

describe Redis::Search do

  describe "configuration" do
    it "does configure have `config` and there attribute" do
      Redis::Search.should respond_to(:config)
      Redis::Search.config.should respond_to(:redis)
      Redis::Search.config.should respond_to(:debug)
      Redis::Search.config.should respond_to(:complete_max_length)
      Redis::Search.config.should respond_to(:pinyin_match)
    end
    
    it "does befor config has success" do
      Redis::Search.config.redis.should == $redis
      Redis::Search.config.complete_max_length.should == 100
      Redis::Search.config.pinyin_match.should == true
      Redis::Search.config.debug.should == false
    end
  end
  
  describe "interfaces" do
    it "does defiend class methods [query,complete,split]" do
      Redis::Search.should respond_to(:query)
      Redis::Search.should respond_to(:complete)
      Redis::Search.should respond_to(:split)
    end
  end
end
