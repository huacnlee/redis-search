require 'spec_helper'

describe Redis::Search do
  describe 'configuration' do
    it 'does configure have `config` and there attribute' do
      Redis::Search.should respond_to(:config)
      Redis::Search.config.should respond_to(:redis)
      Redis::Search.config.should respond_to(:debug)
      Redis::Search.config.should respond_to(:complete_max_length)
      Redis::Search.config.should respond_to(:pinyin_match)
    end

    it 'does befor config has success' do
      Redis::Search.config.redis.should == $redis
      Redis::Search.config.complete_max_length.should == 100
      Redis::Search.config.pinyin_match.should == true
      Redis::Search.config.debug.should == false
    end
  end

  describe 'interfaces' do
    it 'does defiend class methods [query,complete,split]' do
      Redis::Search.should respond_to(:query)
      Redis::Search.should respond_to(:complete)
    end
  end

  describe 'Redis::Search ClassMethods module' do
    before :all do
      @user1 = User.create(email: 'zsf@gmail.com', gender: 1, name: '张三丰', alias: %w(张三疯 张麻子), score: 100, password: '123456')
      @user2 = User.create(email: 'liubei@gmail.com', gender: 2, name: '刘备', score: 200, password: 'abcd')
      @user3 = User.create(email: 'zicheng.lhs@taobao.com', gender: 1, name: '李自成', score: 20, password: 'dsad')
    end

    it 'User.redis_search_index_batch_create should return indices size' do
      User.count.should == User.redis_search_index_batch_create(1000, true)
    end
  end

  describe 'redis search index type' do
    it 'use class name for index type' do
      Admin.create(email: 'zsf@gmail.com', gender: 1, name: '张三丰', alias: %w(张三疯 张麻子), score: 100, password: '123456')
      Redis::Search.complete('Admin', 'zhangsan').count.should == 1
      Redis::Search.complete('Admin', 'zsf').count.should == 1
    end

    it 'allow set index type' do
      Firm.create(name: 'Hollywood')
      Redis::Search.complete('Firm', 'holly').count.should == 0
      Redis::Search.complete('Company', 'holly').count.should == 1
    end
  end
end
