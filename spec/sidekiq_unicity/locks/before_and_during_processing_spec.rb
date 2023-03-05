RSpec.describe SidekiqUnicity::Locks::BeforeAndDuringProcessing do
  before(:each) { SidekiqUnicity.manual_unlock }

  let(:client_conflict_strategy) { SidekiqUnicity::ConflictStrategies::Drop.new }
  let(:server_conflict_strategy) { SidekiqUnicity::ConflictStrategies::Drop.new }
  let(:lock_instance) do
    described_class.new(
      lock_key_proc: ->(args) { args.first },
      client_lock_ttl: 300000,
      server_lock_ttl: 300000,
      client_conflict_strategy:,
      server_conflict_strategy:
    )
    end

  describe '#with_client_lock' do
    before { allow(client_conflict_strategy).to receive(:call).and_call_original }

    subject { lock_instance.with_client_lock(job) { 'processed' } }

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
        expect(client_conflict_strategy).not_to have_received(:call)
      end
    end

    context 'with an already locked job' do
      before { lock_instance.with_client_lock(job.dup) {} }

      it 'rejects the job' do
        expect(subject).to be false
        expect(client_conflict_strategy).to have_received(:call).once
      end
    end

    context 'with another job lock key' do
      before do
        other_job = job.dup.tap { _1['args'] = [2, 'arg', true ] }
        lock_instance.with_client_lock(other_job) {}
      end

      it 'processes the job' do
        expect(subject).to eq('processed')
        expect(client_conflict_strategy).not_to have_received(:call)
      end
    end

    context 'with the job locked for processing' do
      before { lock_instance.with_server_lock(job) {} }

      it 'enqueues the job' do
        expect(subject).to eq('processed')
        expect(client_conflict_strategy).not_to have_received(:call)
      end
    end
  end

  describe '#with_server_lock' do
    before do
      allow(server_conflict_strategy).to receive(:call).and_call_original
      allow(SidekiqUnicity::Locks).to receive(:unlock_job).and_call_original
    end

    subject { lock_instance.with_server_lock(job) { 'processed' } }

    let(:job) do
      {
        "class" => "SomeWorker",
        "jid" => "b4a577edbccf1d805744efa9",
        "args" => [1, "arg", true],
        "created_at" => 1234567890,
        "enqueued_at" => 1234567890
      }
    end

    context 'without before_processing lock info' do
      it 'tries to unlock without failing' do
        expect(subject).to be true
        expect(SidekiqUnicity::Locks).to have_received(:unlock_job).once
      end
    end

    context 'with unknown before_processing lock info' do
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
        expect(subject).to be true
        expect(SidekiqUnicity::Locks).to have_received(:unlock_job).once
      end
    end

    context 'with valid before_processing lock info' do
      before { lock_instance.with_client_lock(job) {} }

      it 'unlocks the job' do
        expect(job).to have_key(SidekiqUnicity::JOB_KWARG_NAME)
        expect(subject).to be true
        expect(SidekiqUnicity::Locks).to have_received(:unlock_job).once
        puts job
        expect(SidekiqUnicity.lock_manager.locked?(job[SidekiqUnicity::JOB_KWARG_NAME]['resource'])).to be false
      end
    end

    context 'when the same job is already locked for processing' do
      before do
        lock_instance.with_client_lock(job) {}
        SidekiqUnicity.lock_manager.lock(lock_instance.send(:build_lock_key, 'during_bd', job), 300000)
      end

      it 'unlocks the job for "before processing" but rejects it for processing' do
        expect(job).to have_key(SidekiqUnicity::JOB_KWARG_NAME)
        expect(subject).to be false
        expect(SidekiqUnicity::Locks).to have_received(:unlock_job).once
        expect(SidekiqUnicity.lock_manager.locked?(job[SidekiqUnicity::JOB_KWARG_NAME]['resource'])).to be false
      end
    end
  end
end
