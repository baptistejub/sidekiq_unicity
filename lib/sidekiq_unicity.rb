require 'redlock'
require 'sidekiq'

require_relative 'sidekiq_unicity/conflict_strategies/drop'
require_relative 'sidekiq_unicity/conflict_strategies/raise'
require_relative 'sidekiq_unicity/conflict_strategies/reschedule'
require_relative 'sidekiq_unicity/job_configurator'
require_relative 'sidekiq_unicity/job'
require_relative 'sidekiq_unicity/locks'
require_relative 'sidekiq_unicity/middleware'
require_relative 'sidekiq_unicity/test_lock_manager'
require_relative 'sidekiq_unicity/version'

module SidekiqUnicity
  class Error < StandardError; end

  Config = Struct.new(:excluded_queues, :default_lock_ttl, :default_conflict_strategy, :redis)

  DEFAULT_LOCK_TTL = 300 # in seconds
  DEFAULT_CONFLICT_STRATEGY = :drop.freeze
  JOB_KWARG_NAME = 'lock_info'.freeze

  def self.configure
    Sidekiq.configure_client do |config|
      config.client_middleware do |chain|
        chain.add Middleware::ClientMiddleware
      end
    end

    Sidekiq.configure_server do |config|
      config.client_middleware do |chain|
        chain.add Middleware::ClientMiddleware
      end

      config.server_middleware do |chain|
        chain.add Middleware::ServerMiddleware
      end
    end

    @config = default_config

    yield @config if block_given?

    @config
  end

  def self.default_config
    Config.new(
      default_lock_ttl: DEFAULT_LOCK_TTL,
      default_conflict_strategy: DEFAULT_CONFLICT_STRATEGY,
      redis: Sidekiq.redis_pool
    )
  end

  def self.config
    @config || default_config
  end

  def self.lock_manager
    @lock_manager ||= Redlock::Client.new([config.redis], retry_count: 0)
  end

  # Manually remove locks from Redis.
  # This method exists "just in case", should not be needed.
  def self.manual_unlock(class_name = nil, unique_arg = nil)
    ['unicity', class_name || '*', '*', unique_arg || '*'].join(':').then do |key|
      config.redis.with { |conn| conn.scan('MATCH', key).each { |k| conn.del(k) } }
    end
  end

  def self.test_mode!
    @lock_manager = TestLockManager.new
  end
end
