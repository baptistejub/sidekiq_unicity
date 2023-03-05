module SidekiqUnicity
  module Locks
    module KeyBuilder
      def build_lock_key(lock_type, job)
        "unicity:#{job['class']}:#{lock_type}:#{@lock_key_proc.call(job['args'])}"
      end
    end
  end
end
