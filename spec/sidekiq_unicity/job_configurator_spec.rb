RSpec.describe SidekiqUnicity::JobConfigurator do
  shared_examples 'global lock configuration' do
    context 'with a custom TTL' do
      let(:options) { { lock:, lock_key_proc: -> {}, lock_ttl: } }

      context 'with an integer' do
        let(:lock_ttl) { 123 }

        it { expect(lock_instance.instance_variable_get('@lock_ttl')).to eq(123000) }
      end

      context 'with an Hash' do
        let(:lock_ttl) { { lock => 124 } }

        it { expect(lock_instance.instance_variable_get('@lock_ttl')).to eq(124000) }
      end
    end

    context 'with a custom conflict strategy' do
      let(:options) { { lock:, lock_key_proc: -> {}, conflict_strategy: } }

      context 'with a built-in strategy' do
        let(:conflict_strategy) { :raise }
        it { expect(lock_instance.instance_variable_get('@conflict_strategy')).to be_a(SidekiqUnicity::ConflictStrategies::Raise) }
      end

      context 'with a custom strategy' do
        let(:conflict_strategy) { ->(*args) { 'resolving conflicts' } }
        it { expect(lock_instance.instance_variable_get('@conflict_strategy')).to eq(conflict_strategy) }
      end
    end
  end

  describe '#configure_lock' do
    subject(:lock_instance) { described_class.new(options, config).configure_lock }

    let(:config) { SidekiqUnicity.config }

    context 'with empty options' do
      let(:options) { {} }
      it { expect { lock_instance }.to raise_error(ArgumentError, /lock key proc/) }
    end

    context 'with a missing lock key proc' do
      let(:options) { { lock: :before_processing } }
      it { expect { lock_instance }.to raise_error(ArgumentError, /lock key proc/) }
    end

    context 'with a missing lock type' do
      let(:options) { { lock_key_proc: -> {} } }
      it { expect { lock_instance }.to raise_error(KeyError, /:lock/) }
    end

    context 'with an invalid lock type' do
      let(:options) { { lock: :unknown, lock_key_proc: -> {} } }
      it { expect { lock_instance }.to raise_error(ArgumentError, /Invalid lock option/) }
    end

    context 'with an invalid lock TTL' do
      let(:options) { { lock: :before_processing, lock_key_proc: -> {}, lock_ttl: 0 } }
      it { expect { lock_instance }.to raise_error(ArgumentError, /Invalid lock TTL/) }
    end

    context 'with an invalid conflict strategy' do
      let(:options) { { lock: :before_processing, lock_key_proc: -> {}, lock_ttl: 5, conflict_strategy: :invalid } }
      it { expect { lock_instance }.to raise_error(ArgumentError, /Invalid conflict strategy/) }
    end

    context 'with a before_processing lock' do
      let(:lock) { :before_processing }
      let(:options) { { lock:, lock_key_proc: -> {} } }

      it { expect(lock_instance).to be_a(SidekiqUnicity::Locks::BeforeProcessing) }

      include_examples 'global lock configuration'
    end

    context 'with a before_and_during_processing lock' do
      let(:lock) { :before_and_during_processing }
      let(:options) { { lock:, lock_key_proc: -> {} } }

      it { expect(lock_instance).to be_a(SidekiqUnicity::Locks::BeforeAndDuringProcessing) }

      context 'with a custom TTL' do
        let(:options) { { lock:, lock_key_proc: -> {}, lock_ttl: } }

        context 'with an integer' do
          let(:lock_ttl) { 123 }

          it {
            expect(lock_instance.instance_variable_get('@client_lock_ttl')).to eq(123000)
            expect(lock_instance.instance_variable_get('@server_lock_ttl')).to eq(123000)
          }
        end

        context 'with an Hash' do
          context 'with a TTL only for one step' do
            let(:lock_ttl) { { during_processing: 124 } }

            it 'uses the default for the other step ' do
              expect(lock_instance.instance_variable_get('@client_lock_ttl')).to eq(config.default_lock_ttl * 1000)
              expect(lock_instance.instance_variable_get('@server_lock_ttl')).to eq(124000)
            end
          end

          context 'with a TTL all steps' do
            let(:lock_ttl) { { during_processing: 124, before_processing: 122 } }

            it 'uses the default for the other step ' do
              expect(lock_instance.instance_variable_get('@client_lock_ttl')).to eq(122000)
              expect(lock_instance.instance_variable_get('@server_lock_ttl')).to eq(124000)
            end
          end

        end
      end

      context 'with a custom conflict strategy' do
        let(:options) { { lock:, lock_key_proc: -> {}, conflict_strategy: } }

        context 'with a built-in strategy' do
          context 'with the same strategy for all steps' do
            let(:conflict_strategy) { :raise }

            it {
              expect(lock_instance.instance_variable_get('@client_conflict_strategy')).to be_a(SidekiqUnicity::ConflictStrategies::Raise)
              expect(lock_instance.instance_variable_get('@server_conflict_strategy')).to be_a(SidekiqUnicity::ConflictStrategies::Raise)
            }
          end

          context 'with the distinct strategy by step' do
            context 'with only one step defined' do
              let(:conflict_strategy) { { before_processing: :raise } }

              it 'fallbacks to the default one for the other' do
                expect(lock_instance.instance_variable_get('@client_conflict_strategy')).to be_a(SidekiqUnicity::ConflictStrategies::Raise)
                expect(lock_instance.instance_variable_get('@server_conflict_strategy')).to be_a(SidekiqUnicity::ConflictStrategies::Drop)
              end
            end

            context 'with only both steps defined' do
              let(:conflict_strategy) { { before_processing: :raise, during_processing: :reschedule } }

              it 'fallbacks to the default one for the other' do
                expect(lock_instance.instance_variable_get('@client_conflict_strategy')).to be_a(SidekiqUnicity::ConflictStrategies::Raise)
                expect(lock_instance.instance_variable_get('@server_conflict_strategy')).to be_a(SidekiqUnicity::ConflictStrategies::Reschedule)
              end
            end

            context 'with custom options for the strategy' do
              let(:conflict_strategy) { { before_processing: :drop, during_processing: { name: :reschedule, options: { cool_down_duration: 15 } } } }

              it 'registers the options' do
                expect(lock_instance.instance_variable_get('@client_conflict_strategy')).to be_a(SidekiqUnicity::ConflictStrategies::Drop)
                expect(lock_instance.instance_variable_get('@server_conflict_strategy')).to be_a(SidekiqUnicity::ConflictStrategies::Reschedule)
                expect(lock_instance.instance_variable_get('@server_conflict_strategy').instance_variable_get('@cool_down_duration')).to eq(15)
              end
            end
          end
        end

        context 'with a custom strategy' do
          let(:conflict_strategy) { ->(*args) { 'resolving conflicts' } }
          it {
            expect(lock_instance.instance_variable_get('@client_conflict_strategy')).to eq(conflict_strategy)
            expect(lock_instance.instance_variable_get('@server_conflict_strategy')).to eq(conflict_strategy)
          }
        end
      end
    end

    context 'with a during_processing lock' do
      let(:lock) { :during_processing }
      let(:options) { { lock:, lock_key_proc: -> {} } }

      it { expect(lock_instance).to be_a(SidekiqUnicity::Locks::DuringProcessing) }

      include_examples 'global lock configuration'
    end

    context 'with a until_processed lock' do
      let(:lock) { :until_processed }
      let(:options) { { lock:, lock_key_proc: -> {} } }

      it { expect(lock_instance).to be_a(SidekiqUnicity::Locks::UntilProcessed) }

      include_examples 'global lock configuration'
    end
  end
end
