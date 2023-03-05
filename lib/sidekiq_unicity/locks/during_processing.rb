require_relative 'key_builder'

module SidekiqUnicity
  module Locks
    class DuringProcessing
      include KeyBuilder

      def initialize(lock_key_proc:, lock_ttl:, conflict_strategy:)
        @lock_key_proc = lock_key_proc
        @lock_ttl = lock_ttl
        @conflict_strategy = conflict_strategy
      end

      def for_client? = false
      def for_server? = true

      def with_server_lock(job)
        key = build_lock_key('during', job)

        Locks.with_lock(key, @lock_ttl) do |locked|
          if locked
            yield
          else
            @conflict_strategy.call(job, key)
            false
          end
        end
      end
    end
  end
end
