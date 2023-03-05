module SidekiqUnicity
  module Middleware
    module Base
      def call(_worker, job, queue, *_args)
        Object.const_get(job['class']).sidekiq_unicity_lock.then do |lock|
          # Checking excluded queue last to avoid unnecessary lookups
          if apply_lock?(lock) && !SidekiqUnicity.config.excluded_queues&.include?(queue)
            with_lock(lock, job) { yield }
          else
            yield
          end
        end
      end
    end

    class ClientMiddleware
      include Sidekiq::ClientMiddleware
      include Base

      def apply_lock?(lock)
        lock&.for_client?
      end

      def with_lock(lock, job, &)
        lock.with_client_lock(job, &)
      end
    end

    class ServerMiddleware
      include Sidekiq::ServerMiddleware
      include Base

      def apply_lock?(lock)
        lock&.for_server?
      end

      def with_lock(lock, job, &)
        lock.with_server_lock(job, &)
      end
    end
  end
end
