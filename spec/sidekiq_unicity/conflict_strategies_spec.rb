RSpec.describe SidekiqUnicity::ConflictStrategies do
  describe SidekiqUnicity::ConflictStrategies::Drop do
    subject { described_class.new.call({ 'jid' => 'sidekiq_jid' }, 'unicity:key') }

    before { allow(Sidekiq.logger).to receive(:info).and_call_original }

    it {
      expect(subject).to be true
      expect(Sidekiq.logger).to have_received(:info)
    }
  end

  describe SidekiqUnicity::ConflictStrategies::Raise do
    subject { described_class.new.call({ 'jid' => 'sidekiq_jid' }, 'unicity:key') }

    it { expect { subject }.to raise_error(SidekiqUnicity::Error) }
  end

  describe SidekiqUnicity::ConflictStrategies::Reschedule do
    class TestConflictJob
      include Sidekiq::Job

      def perform
      end
    end

    subject { described_class.new.call({ 'jid' => 'sidekiq_jid', 'class' => 'TestConflictJob', 'queue' => 'default' }, 'unicity:key') }

    before do
      allow(TestConflictJob).to receive(:set).and_return(TestConflictJob)
      allow(TestConflictJob).to receive(:perform_in).and_return('enqueued')
    end

    it { expect(subject).to eq('enqueued') }
  end
end
