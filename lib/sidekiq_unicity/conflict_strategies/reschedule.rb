module SidekiqUnicity
  module ConflictStrategies
    class Reschedule
      DEFAULT_COOL_DOWN_DURATION = 5 # in seconds

      def initialize(cool_down_duration: nil)
        @cool_down_duration = cool_down_duration || DEFAULT_COOL_DOWN_DURATION
      end

      def call(job, _lock_key)
        Object.const_get(job['class']).set(queue: job['queue']).perform_in(@cool_down_duration, *job['args'])
      end
    end
  end
end
