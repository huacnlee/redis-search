require 'spec_helper'

describe 'Redis::Search Finders' do
  before do
    @user1 = User.create(email: 'zsf@gmail.com', gender: 1, name: '张三丰', alias: %w(张三疯 张麻子), score: 100, password: '123456')
    @user2 = User.create(email: 'liubei@gmail.com', gender: 2, name: '刘备', score: 200, password: 'abcd')
    @user3 = User.create(email: 'zicheng.lhs@taobao.com', gender: 1, name: '李自成', score: 20, password: 'dsad')
    @user4 = User.create(email: 'zhang-wuji@me.com', gender: 1, name: '张无忌', score: 2000, password: '123456762')
    @user5 = User.create(email: 'liao.zhang@apple.com', gender: 0, name: '张辽', score: 700, password: 'abcdks')
    @user6 = User.create(email: 'leo-cheng@gmail.com', gender: 2, name: 'Leo Peter Cheng', score: 3, password: 'kdhs')

    @category1 = Category.create(name: 'Programming')
    @category2 = Category.create(name: 'My live')

    @post1 = Post.create(user: @user1,
                         category: @category1,
                         title: 'How do I check If a Class already exists in Ruby',
                         hits: 32_182)
    @post2 = Post.create(user: @user3,
                         category: @category2,
                         title: '新版本上线，采用 Twitter 的 Bootstrap 来设计布局',
                         hits: 100)
    @post3 = Post.create(user: @user3,
                         category: @category1,
                         title: 'redis-search 高效的 Ruby 搜索插件介绍',
                         hits: 2000)
    @post4 = Post.create(user: @user2,
                         category: @category1,
                         title: 'What different of Ruby Class and Module?',
                         hits: 6721)
    @post5 = Post.create(user: @user5,
                         category: @category1,
                         title: 'Redis is a right store way for Ruby on Rails project?',
                         hits: 762)
  end

  describe 'init data should be fine' do
    it 'does users create fine' do
      User.count.should == 6
    end

    it 'does categories create fine' do
      Category.count.should == 2
    end

    it 'does posts create fine' do
      Post.count.should == 5
    end
  end

  describe '[Complete] method' do
    it 'does Chinese can complete with prefix' do
      items = Redis::Search.complete('User', '张')
      items.count.should == 3

      User.prefix_match('张').should == items

      Redis::Search.complete('User', '张').count.should == 3
      Redis::Search.complete('User', '张三').count.should == 1
      Redis::Search.complete('User', '张三丰').count.should == 1

      User.prefix_match('张三').count.should == 1
    end

    it 'should search with alias' do
      Redis::Search.complete('User', '张三疯').count.should == 1
      Redis::Search.complete('User', '张麻').count.should == 1
      Redis::Search.complete('User', '张麻子').count.should == 1
    end

    it 'should search with Pinyin first chars' do
      Redis::Search.complete('User', 'z').count.should == 3
      Redis::Search.complete('User', 'zs').count.should == 1
      Redis::Search.complete('User', 'zm').count.should == 1
      Redis::Search.complete('User', 'zmz').count.should == 1
      Redis::Search.complete('User', 'zsf').count.should == 1
    end

    it 'does Pinyin can complete with prefix' do
      items = Redis::Search.complete('User', 'z')
      items.count.should == 3

      Redis::Search.complete('User', 'zhangs').count.should == 1
      Redis::Search.complete('User', 'zhangl').count.should == 1
      Redis::Search.complete('User', 'zhangn').count.should == 0
      Redis::Search.complete('User', 'zh').count.should == 3
      Redis::Search.complete('User', 'zha').count.should == 3
      Redis::Search.complete('User', 'zhan').count.should == 3
      Redis::Search.complete('User', 'zhangw').count.should == 1
      Redis::Search.complete('User', 'zhangw')[0]['id'].should == @user4.id
    end

    it 'does can return defined attributes' do
      Redis::Search.complete('User', '张三')[0].keys.should == %w(title id type email score gender)
    end

    it 'does can return right attribute values' do
      item = Redis::Search.complete('User', '张三')[0]
      item['id'].should == @user1.id
      item['title'].should == @user1.name
      item['email'].should == @user1.email
      item['score'].should == @user1.score
    end

    it 'does can return desc order' do
      items = Redis::Search.complete('User', 'z')
      items[0]['id'].should == @user4.id
      items[1]['id'].should == @user5.id
      items[2]['id'].should == @user1.id
    end

    it 'does can return asc order' do
      items = Redis::Search.complete('User', 'z', order: 'asc')
      items[0]['id'].should == @user1.id
      items[1]['id'].should == @user5.id
      items[2]['id'].should == @user4.id
    end

    it 'does support English' do
      items = Redis::Search.complete('User', 'l')
      items.count.should == 3
      items[0]['id'].should == @user2.id
      items[1]['id'].should == @user3.id
      items[2]['id'].should == @user6.id
    end

    it 'does will return [] when search key is null or found no result' do
      Redis::Search.complete('User', '').should == []
      Redis::Search.complete('User', nil).should == []
      Redis::Search.complete('', nil).should == []
      Redis::Search.complete('User', 'adslgkjaslkdgjalksdgj').should == []
    end

    it 'does search with conditions' do
      Redis::Search.complete('User', 'l', conditions: [gender: 2]).count.should == 2
      Redis::Search.complete('User', 'li', conditions: [gender: 2]).count.should == 1
    end

    it 'does search only by conditions' do
      Redis::Search.complete('User', '', conditions: [gender: 1]).count.should == 3
      Redis::Search.complete('User', '', conditions: [gender: 2]).count.should == 2
      Redis::Search.complete('User', '', conditions: [gender: 0]).count.should == 1
    end
  end
end
