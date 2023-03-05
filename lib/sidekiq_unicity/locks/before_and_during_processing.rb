require_relative 'key_builder'

module SidekiqUnicity
  module Locks
    class BeforeAndDuringProcessing
      include KeyBuilder

      def initialize(lock_key_proc:, client_lock_ttl:, server_lock_ttl:, client_conflict_strategy:, server_conflict_strategy:)
        @lock_key_proc = lock_key_proc
        @client_lock_ttl = client_lock_ttl
        @client_conflict_strategy = client_conflict_strategy
        @server_lock_ttl = server_lock_ttl
        @server_conflict_strategy = server_conflict_strategy
      end

      def for_client? = true
      def for_server? = true

      def with_client_lock(job)
        key = build_lock_key('before_bd', job)

        if Locks.lock_job_from_client!(job, key, @client_lock_ttl)
          yield
        else
          @client_conflict_strategy.call(job, key)
          false
        end
      end

      def with_server_lock(job)
        key = build_lock_key('during_bd', job)

        Locks.with_lock(key, @server_lock_ttl) do |processing_locked|
          Locks.unlock_job(job)

          if processing_locked
            yield
          else
            @server_conflict_strategy.call(job, key)
            false
          end
        end
      end
    end
  end
end
