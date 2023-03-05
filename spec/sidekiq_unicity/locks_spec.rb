RSpec.describe SidekiqUnicity::Locks do
  before(:each) { SidekiqUnicity.manual_unlock }

  describe '.with_lock' do
    subject { locked = nil; described_class.with_lock(key, ttl) { locked = _1 }; locked }
    let(:key) { 'unicity:test_lock:lock_type:arg' }
    let(:ttl) { 50000 }

    context 'when the lock is available' do
      it 'locks the key and releases it' do
        expect(subject).to be_a(Hash)
        expect(SidekiqUnicity.lock_manager.locked?(key)).to be false
      end
    end

    context 'when the lock already exists' do
      before { SidekiqUnicity.lock_manager.lock(key, ttl) }

      it 'does not relock the key' do
        expect(SidekiqUnicity.lock_manager.locked?(key)).to be true
        expect(subject).to be false
        expect(SidekiqUnicity.lock_manager.locked?(key)).to be true
      end
    end
  end

  describe '.lock_job_from_client!' do
    subject { described_class.lock_job_from_client!(job, key, ttl) }

    let(:job) { {} }
    let(:key) { 'unicity:test_lock:lock_type:arg' }
    let(:ttl) { 50000 }

    context 'when the lock is available' do
      it 'locks the key' do
        expect(subject).to be_a(Hash)
        expect(job['lock_info']).to eq(subject)
        expect(SidekiqUnicity.lock_manager.locked?(key)).to be true
      end
    end

    context 'when the lock already exists' do
      before { SidekiqUnicity.lock_manager.lock(key, ttl) }

      it 'does not relock the key' do
        expect(subject).to be_nil
        expect(job['lock_info']).to be_nil
        expect(SidekiqUnicity.lock_manager.locked?(key)).to be true
      end
    end

    context 'when the lock is already acquired by he job' do
      before { described_class.lock_job_from_client!(job, key, 20000) }

      it 'extends the lock' do
        previous_lock_info = job['lock_info']
        expect(subject).to be_a(Hash)
        expect(job['lock_info']).to eq(subject)
        expect(previous_lock_info).not_to eq(subject)
        expect(SidekiqUnicity.lock_manager.locked?(key)).to be true
      end
    end
  end

  describe '.unlock_job' do
    subject { described_class.unlock_job(job) }

    let(:job) { {} }
    let(:key) { 'unicity:test_lock:lock_type:arg' }
    let(:ttl) { 50000 }

    context 'without any lock info' do
      it 'does nothing' do
        expect(subject).to be_nil
      end
    end

    context 'with an unlocked resource' do
      let(:job) { { 'lock_info' => { 'resource' => 'test' } } }

      it 'tries to unlock' do
        expect(subject).not_to be_nil
      end
    end

    context 'with a locked resource' do
      before { described_class.lock_job_from_client!(job, key, ttl) }

      it 'unlocks the job' do
        expect(SidekiqUnicity.lock_manager.locked?(key)).to be true
        expect(subject).not_to be_nil
        expect(SidekiqUnicity.lock_manager.locked?(key)).to be false
      end
    end
  end
end
