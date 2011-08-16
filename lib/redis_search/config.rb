module RedisSearch
  class << self
    attr_accessor :config
  end
  
  class Config
    attr_accessor :redis, :debug
    
    def initialize
      self.debug = false
      self.redis = nil
    end
  end
end