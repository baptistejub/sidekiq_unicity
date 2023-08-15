module SidekiqUnicity
  module Locks
    class Manager
      attr_reader :redlock

      def initialize(redis)
        @redlock = Redlock::Client.new([redis], retry_count: 0)
      end

      def locked?(key)
        redlock.locked?(key)
      end

      def lock(key, ttl)
        redlock.lock(key, ttl)
      end

      def with_lock(key, ttl, &)
        redlock.lock(key, ttl, &)
      end

      def lock_job_from_client!(job, key, ttl)
        lock_info = job[SidekiqUnicity::JOB_KWARG_NAME]&.transform_keys(&:to_sym)

        # Jobs are unique across (included) queues, including retry and scheduled job queues.
        # Moving a job between queues calls the client middleware stack, thus tries to acquire the lock.
        # For a job already owning the lock, we can't acquire a new lock, so we extend it instead
        # (to avoid deadlock or infinite loop).
        job[SidekiqUnicity::JOB_KWARG_NAME] = redlock.lock(
          key,
          ttl,
          extend: lock_info,
          extend_only_if_locked: !!lock_info
        ).then { _1.transform_keys(&:to_s) if _1 }
      end

      def unlock_job(job)
        job[SidekiqUnicity::JOB_KWARG_NAME].then do
          redlock.unlock(_1.transform_keys(&:to_sym)) if _1
        end
      end
    end
  end
end
