module SidekiqUnicity
  module Job
    def sidekiq_unicity_options(options)
      # Fully prepare the necessary lock instance on setup to limit overhead in the middleware
      @sidekiq_unicity_lock = JobConfigurator.new(options, SidekiqUnicity.config).configure_lock
    end

    def sidekiq_unicity_lock
      @sidekiq_unicity_lock
    end
  end
end

Sidekiq::Job::ClassMethods.module_eval { include SidekiqUnicity::Job }
