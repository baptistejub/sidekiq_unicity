require_relative 'key_builder'

module SidekiqUnicity
  module Locks
    class UntilProcessed
      include KeyBuilder

      def initialize(lock_key_proc:, lock_ttl:, conflict_strategy:)
        @lock_key_proc = lock_key_proc
        @lock_ttl = lock_ttl
        @conflict_strategy = conflict_strategy
      end

      def for_client? = true
      def for_server? = true

      def with_client_lock(job, lock_manager)
        key = build_lock_key('until', job)

        if lock_manager.lock_job_from_client!(job, key, @lock_ttl)
          yield
        else
          @conflict_strategy.call(job, key)
          false
        end
      end

      def with_server_lock(job, lock_manager)
        yield
      ensure
        lock_manager.unlock_job(job)
      end
    end
  end
end
