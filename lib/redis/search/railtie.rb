class Redis
  module Search
    class Railtie < Rails::Railtie
      rake_tasks do
        load File.expand_path('../tasks.rb', __FILE__)
      end
    end
  end
end