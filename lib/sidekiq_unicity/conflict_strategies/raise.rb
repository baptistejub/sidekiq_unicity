module SidekiqUnicity
  module ConflictStrategies
    class Raise
      def call(job, lock_key)
        raise SidekiqUnicity::Error, "Duplicated job #{job['class']} with lock key #{lock_key}"
      end
    end
  end
end
