RSpec.describe SidekiqUnicity::Locks::BeforeProcessing do
  before(:each) { SidekiqUnicity.manual_unlock }

  let(:conflict_strategy) { SidekiqUnicity::ConflictStrategies::Drop.new }
  let(:lock_instance) { described_class.new(lock_key_proc: ->(job) { job['args'].first }, lock_ttl: 300000, conflict_strategy:) }
  let(:lock_manager) { SidekiqUnicity::Locks::Manager.new(Sidekiq.redis_pool) }

  describe '#with_client_lock' do
    before { allow(conflict_strategy).to receive(:call).and_call_original }

    subject { lock_instance.with_client_lock(job, lock_manager) { 'processed' } }

    let(:job) do
      {
        "class" => "SomeWorker",
        "jid" => "b4a577edbccf1d805744efa9",
        "args" => [1, "arg", true],
        "created_at" => 1234567890,
        "enqueued_at" => 1234567890
      }
    end

    context 'without any locked job' do
      it 'processes the job' do
        expect(subject).to eq('processed')
        expect(conflict_strategy).not_to have_received(:call)
      end
    end

    context 'with an already locked job' do
      before { lock_instance.with_client_lock(job.dup, lock_manager) {} }

      it 'rejects the job' do
        expect(subject).to be false
        expect(conflict_strategy).to have_received(:call).once
      end
    end

    context 'with another job lock key' do
      before do
        other_job = job.dup.tap { _1['args'] = [2, 'arg', true] }
        lock_instance.with_client_lock(other_job, lock_manager) {}
      end

      it 'processes the job' do
        expect(subject).to eq('processed')
        expect(conflict_strategy).not_to have_received(:call)
      end
    end
  end

  describe '#with_server_lock' do
    before { allow(lock_manager).to receive(:unlock_job).and_call_original }

    subject { lock_instance.with_server_lock(job, lock_manager) { 'processed' } }

    let(:job) do
      {
        "class" => "SomeWorker",
        "jid" => "b4a577edbccf1d805744efa9",
        "args" => [1, "arg", true],
        "created_at" => 1234567890,
        "enqueued_at" => 1234567890
      }
    end

    context 'without lock info' do
      it 'tries to unlock without failing' do
        expect(subject).to eq('processed')
        expect(lock_manager).to have_received(:unlock_job).once
      end
    end

    context 'with unknown lock info' do
      let(:job) do
        {
          "class" => "SomeWorker",
          "jid" => "b4a577edbccf1d805744efa9",
          "args" => [1, "arg", true],
          "created_at" => 1234567890,
          "enqueued_at" => 1234567890,
          SidekiqUnicity::JOB_KWARG_NAME => { "validity" => 1987, "resource" => "resource_key", "value" => "generated_uuid4" }
        }
      end

      it 'tries to unlock without failing' do
        expect(subject).to eq('processed')
        expect(lock_manager).to have_received(:unlock_job).once
      end
    end

    context 'with valid lock info' do
      before { lock_instance.with_client_lock(job, lock_manager) {} }

      it 'unlocks the job' do
        expect(job).to have_key(SidekiqUnicity::JOB_KWARG_NAME)
        expect(subject).to eq('processed')
        expect(lock_manager).to have_received(:unlock_job).once
        expect(lock_manager.locked?(job[SidekiqUnicity::JOB_KWARG_NAME])).to be false
      end
    end
  end
end
