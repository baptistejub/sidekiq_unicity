require_relative 'locks/manager'

module SidekiqUnicity
  module Middleware
    module Base
      def call(_worker, job, queue, *_args)
        Object.const_get(job['class']).sidekiq_unicity_lock.then do |lock|
          # Checking excluded queue last to avoid unnecessary lookups
          if lock && apply_lock?(lock) && !SidekiqUnicity.config.excluded_queues&.include?(queue)
            with_lock(lock, job) { yield }
          else
            yield
          end
        end
      end

      private

      def lock_manager
        @lock_manager ||= SidekiqUnicity::Locks::Manager.new(redis_pool)
      end
    end

    class ClientMiddleware
      include Sidekiq::ClientMiddleware
      include Base

      def apply_lock?(lock)
        lock.for_client?
      end

      def with_lock(lock, job, &)
        lock.with_client_lock(job, lock_manager, &)
      end
    end

    class ServerMiddleware
      include Sidekiq::ServerMiddleware
      include Base

      def apply_lock?(lock)
        lock.for_server?
      end

      def with_lock(lock, job, &)
        lock.with_server_lock(job, lock_manager, &)
      end
    end
  end
end
