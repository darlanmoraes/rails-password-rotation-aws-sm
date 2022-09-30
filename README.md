### Purpose

This is an attempt to make `Rails` support password rotation while keeping new connections working. The [connection_pool.rb](./config/initializers/connection_pool.rb) file will be responsible by creating new connections for `ActiveRecord`. It will try to load configuration data from `AWS Secrets Manager` and then create the connection to the database. The configuration data is cached in `Rails` for new connections, so we don't keep it pooling `AWS`.

When the password rotates, the current connections will keep working because that is how `Postgres` works. New connections will fail with the old configuration data in the cache, but the code will then reload this from `AWS` and update the cache, re-attempting the connection.

I executed a few tests with this and it has been working pretty well, evicting errors in the `Rails` application and keeping it running.

The configuration from `database.yml` for `host`, `port`, `username`, `password` and `database` are completely ignored in this version.

This was based on this [repository](https://github.com/zygotecnologia/activerecord-aws-secret-connector).

```
➜  rails-password-rotation-aws-sm git:(master) ✗ rails db:create
> Reading from Rails cache
> Reading from AWS # Cache miss, going to AWS
> New connection: host=127.0.0.1, pass=wrong-pass # Loaded a password that won't work
> Error connecting. Refreshing secrets
# After this, the application will wait a few seconds
# I updated the password to the correct one, then after 10s the application
# expired the cache and connect to AWS again to get the connection information
> Reading from Rails cache
> Reading from AWS
> New connection: host=127.0.0.1, pass=correct-pass
> Created database 'rotation_development' # The new password works fine
> Reading from Rails cache # Now the cache is used, the password is correct
> New connection: host=127.0.0.1, pass=correct-pass
> Created database 'rotation_test'
```