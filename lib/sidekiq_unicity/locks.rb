require_relative 'locks/before_processing'
require_relative 'locks/before_and_during_processing'
require_relative 'locks/during_processing'
require_relative 'locks/until_processed'

module SidekiqUnicity
  module Locks
    def self.with_lock(key, ttl, &)
      SidekiqUnicity.lock_manager.lock(key, ttl, &)
    end

    def self.lock_job_from_client!(job, key, ttl)
      lock_info = job[SidekiqUnicity::JOB_KWARG_NAME]&.transform_keys(&:to_sym)

      # Jobs are unique across (included) queues, including retry and scheduled job queues.
      # Moving a job between queues calls the client middleware stack, thus tries to acquire the lock.
      # For a job already owning the lock, we can acquire a new lock, so we extend it instead
      # (to avoid deadlock or infinite loop).
      job[SidekiqUnicity::JOB_KWARG_NAME] = SidekiqUnicity.lock_manager.lock(
        key,
        ttl,
        extend: lock_info,
        extend_only_if_locked: !!lock_info
      ).then { _1.transform_keys(&:to_s) if _1 }
    end

    def self.unlock_job(job)
      job[SidekiqUnicity::JOB_KWARG_NAME].then do
        SidekiqUnicity.lock_manager.unlock(_1.transform_keys(&:to_sym)) if _1
      end
    end
  end
end
