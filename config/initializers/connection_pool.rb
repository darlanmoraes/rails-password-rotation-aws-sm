module ActiveRecord
  module ConnectionAdapters
    class ConnectionPool
      private

      # Overrides default new_connection method from active record
      # to verify if database.yml has an aws_secret key
      # It uses the aws_secret from database.yml to get
      # all database connection informations from aws secret
      # and possibly cache it to use it later easier
      # when this key is present.
      # Otherwise, just work as normal connection for activerecord default feature
      def new_connection
        logger = ActiveSupport::TaggedLogging.new(Logger.new(STDOUT))
        config = spec.config

        database_info = self.database_config_from_secret
        logger.info "Getting new connection with: #{database_info.inspect}"

        config.merge!(
          host: database_info["host"],
          port: database_info["port"],
          database: database_info["dbname"],
          username: database_info["username"],
          password: database_info["password"]
        )

        Base.send(spec.adapter_method, config).tap do |conn|
          conn.check_version
        end
      end

      def database_config_from_secret
        client = Aws::SecretsManager::Client.new({
          :region => "<MY-REGION>",
          :profile => "<MY-PROFILE>"
        })

        JSON.parse(client.get_secret_value(secret_id: "<MY-SECRET-ID>").secret_string)
      end
    end
  end
end