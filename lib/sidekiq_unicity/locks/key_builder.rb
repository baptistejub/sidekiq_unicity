module SidekiqUnicity
  module Locks
    module KeyBuilder
      def build_lock_key(lock_type, job, custom_lock_key_proc = nil)
        "unicity:#{job['class']}:#{lock_type}:#{(custom_lock_key_proc || @lock_key_proc).call(job)}"
      end
    end
  end
end
