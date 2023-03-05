module SidekiqUnicity
  class JobConfigurator
    attr_reader :config, :options

    def initialize(options, config)
      @options = options
      @config = config
    end

    def configure_lock
      lock_key_proc = options.fetch(:lock_key_proc, nil)
      raise ArgumentError, 'Invalid lock key proc' unless lock_key_proc.is_a?(Proc)

      case options.fetch(:lock).to_sym
      when :before_processing
        Locks::BeforeProcessing.new(
          lock_key_proc:,
          lock_ttl: fetch_lock_ttl(:before_processing),
          conflict_strategy: configure_conflict_strategy(:before_processing),
        )
      when :during_processing
        Locks::DuringProcessing.new(
          lock_key_proc:,
          lock_ttl: fetch_lock_ttl(:during_processing),
          conflict_strategy: configure_conflict_strategy(:during_processing)
        )
      when :before_and_during_processing
        Locks::BeforeAndDuringProcessing.new(
          lock_key_proc:,
          client_lock_ttl: fetch_lock_ttl(:before_processing),
          server_lock_ttl: fetch_lock_ttl(:during_processing),
          client_conflict_strategy: configure_conflict_strategy(:before_processing),
          server_conflict_strategy: configure_conflict_strategy(:during_processing)
        )
      when :until_processed
        Locks::UntilProcessed.new(
          lock_key_proc:,
          lock_ttl: fetch_lock_ttl(:until_processed),
          conflict_strategy: configure_conflict_strategy(:until_processed)
        )
      else
        raise ArgumentError, "Invalid lock option: #{options[:lock]}"
      end
    end

    private

    # Possible formats:
    #  - { lock_ttl: 123 }
    #  - { lock_ttl: { before_processing: 123, during_processing: 456 } }
    def fetch_lock_ttl(type)
      lock_ttls = options.fetch(:lock_ttl, nil)
      return config.default_lock_ttl * 1_000 unless lock_ttls

      lock_ttl = lock_ttls.is_a?(Hash) ? lock_ttls.fetch(type, config.default_lock_ttl) : lock_ttls

      raise ArgumentError, "Invalid lock TTL for #{type}: #{lock_ttl}" if lock_ttl.to_i.zero?

      # in milliseconds
      lock_ttl.to_i * 1_000
    end

    # Possible formats:
    #  - { conflict_strategy: :drop }
    #  - { conflict_strategy: Proc.new { |job, lock_key| puts lock_key } }
    #  - { conflict_strategy: { before_processing: :drop, during_processing: :reschedule } }
    #  - { conflict_strategy: { before_processing: :drop, during_processing: { name: :reschedule, options: { cool_down_duration: 15 } } } }
    def configure_conflict_strategy(type)
      strategies = options.fetch(:conflict_strategy, config.default_conflict_strategy)
      return strategies if strategies.respond_to?(:call)

      strategy = strategies.is_a?(Hash) ? strategies.fetch(type, config.default_conflict_strategy) : strategies
      return strategy if strategy.respond_to?(:call)

      strategy_name, options = strategy.is_a?(Hash) ? [strategy.fetch(:name), strategy.fetch(:options, {})] : [strategy, {}]

      case strategy_name&.to_sym
      when :drop
        ConflictStrategies::Drop.new
      when :raise
        ConflictStrategies::Raise.new
      when :reschedule
        ConflictStrategies::Reschedule.new(**options)
      else
        raise ArgumentError, "Invalid conflict strategy for #{type}: #{strategy}"
      end
    end
  end
end
