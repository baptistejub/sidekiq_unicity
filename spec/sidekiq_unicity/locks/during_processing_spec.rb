RSpec.describe SidekiqUnicity::Locks::DuringProcessing do
  before(:each) { SidekiqUnicity.manual_unlock }

  let(:conflict_strategy) { SidekiqUnicity::ConflictStrategies::Drop.new }
  let(:lock_instance) { described_class.new(lock_key_proc: ->(job) { job['args'].first }, lock_ttl: 300000, conflict_strategy:) }
  let(:lock_manager) { SidekiqUnicity::Locks::Manager.new(Sidekiq.redis_pool) }

  describe '#with_server_lock' do
    subject { lock_instance.with_server_lock(job, lock_manager) {} }

    let(:job) do
      {
        "class" => "SomeWorker",
        "jid" => "b4a577edbccf1d805744efa9",
        "args" => [1, "arg", true],
        "created_at" => 1234567890,
        "enqueued_at" => 1234567890
      }
    end

    context 'with an unlocked job' do
      it 'locks and unlocks' do
        expect(subject).to be true
        expect(lock_instance.with_server_lock(job, lock_manager) {}).to be true
      end
    end

    context 'with a locked job' do
      before do
        lock_manager.lock(lock_instance.send(:build_lock_key, 'during', job), 300000)
      end

      it 'skips the same job' do
        expect(subject).to be false
      end

      it 'accepts another job' do
        other_job = {
          "class" => "SomeWorker",
          "jid" => "b4a577edbccf1d805744efa8",
          "args" => [2, "arg", true],
          "created_at" => 1234567890,
          "enqueued_at" => 1234567890
        }

        expect(lock_instance.with_server_lock(other_job, lock_manager) {}).to be true
      end
    end
  end
end
