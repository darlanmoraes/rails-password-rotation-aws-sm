module ActiveRecord
  module ConnectionAdapters
    class ConnectionPool

      DATABASE_SECRET_CACHE_KEY = "DATABASE_SECRET_FOR_#{Rails.env.upcase}"

      private
      # Overrides default new_connection method from active record
      # to verify if database.yml has an aws_secret key
      # It uses the aws_secret from database.yml to get
      # all database connection informations from aws secret
      # and possibly cache it to use it later easier
      # when this key is present.
      # Otherwise, just work as normal connection for activerecord default feature
      def new_connection
        begin
          # Loading with the current configuration from cache
          self.pg_connect
        rescue
          # Oops, wrong password
          logger.info "Error connecting. Refreshing secrets"
          # Force the cache to be updated
          self.clear_cache
          # Loading with updated configuration
          self.pg_connect
        end
      end

      def pg_connect
        config = spec.config

        has_aws_secret = (spec.config.key? :aws_secret) && spec.config[:aws_secret] != nil
        if has_aws_secret
          self.load_and_merge_config(config)
        end

        Base.send(spec.adapter_method, config).tap do |conn|
          conn.check_version
        end
      end

      def load_and_merge_config(config)
        configuration = self.get_connection_info_from_cache
        logger.info "New connection: host=#{configuration["host"]}, pass=#{configuration["password"]}"

        config.merge!(
          host: configuration["host"],
          port: configuration["port"],
          database: configuration["dbname"],
          username: configuration["username"],
          password: configuration["password"]
        )
      end

      # Read the secret values from AWS
      def get_connection_info_from_aws
        logger.info "Reading from AWS secret"
        client = Aws::SecretsManager::Client.new

        aws_secret = spec.config[:aws_secret]
        JSON.parse(client.get_secret_value(secret_id: aws_secret).secret_string)
      end

      # Caches the secret values for 60min
      def get_connection_info_from_cache
        logger.info "Reading from Rails cache"
        Rails.cache.fetch(DATABASE_SECRET_CACHE_KEY, expires_in: nil) do
          get_connection_info_from_aws
        end
      end

      def clear_cache
        Rails.cache.delete(DATABASE_SECRET_CACHE_KEY)
      end

      def logger
        @logger ||= ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
      end
    end
  end
end