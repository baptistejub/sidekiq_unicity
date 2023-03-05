module SidekiqUnicity
  module ConflictStrategies
    class Drop
      def call(job, lock_key)
        Sidekiq::Context.with(unicity_lock_key: lock_key) do
          Sidekiq.logger.info("SidekiqUnicity: dropping duplicated job #{job['jid']} with key #{lock_key}")
        end
      end
    end
  end
end
