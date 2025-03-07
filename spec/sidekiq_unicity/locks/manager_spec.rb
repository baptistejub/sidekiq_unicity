RSpec.describe SidekiqUnicity::Locks::Manager do
  before(:each) { SidekiqUnicity.manual_unlock }
  let(:instance) { described_class.new(Sidekiq.redis_pool) }

  describe '.with_lock' do
    subject { locked = nil; instance.with_lock(key, ttl) { locked = _1 }; locked }
    let(:key) { 'unicity:test_lock:lock_type:arg' }
    let(:ttl) { 50000 }

    context 'when the lock is available' do
      it 'locks the key and releases it' do
        expect(subject).to be_a(Hash)
        expect(instance.locked?(key)).to be false
      end
    end

    context 'when the lock already exists' do
      before { instance.lock(key, ttl) }

      it 'does not relock the key' do
        expect(instance.locked?(key)).to be true
        expect(subject).to be false
        expect(instance.locked?(key)).to be true
      end
    end
  end

  describe '.lock_job_from_client!' do
    subject { instance.lock_job_from_client!(job, key, ttl) }

    let(:job) { {} }
    let(:key) { 'unicity:test_lock:lock_type:arg' }
    let(:ttl) { 50000 }

    context 'when the lock is available' do
      it 'locks the key' do
        expect(subject).to be_a(Hash)
        expect(job['lock_info']).to eq(subject)
        expect(instance.locked?(key)).to be true
      end
    end

    context 'when the lock already exists' do
      before { instance.lock(key, ttl) }

      it 'does not relock the key' do
        expect(subject).to be_nil
        expect(job['lock_info']).to be_nil
        expect(instance.locked?(key)).to be true
      end
    end

    context 'when the lock is already acquired by he job' do
      let(:prev_ttl) { 20000 }

      before { instance.lock_job_from_client!(job, key, prev_ttl) }

      it 'extends the lock' do
        previous_lock_info = job['lock_info']
        expect(subject).to be_a(Hash)
        expect(job['lock_info']).to eq(subject)
        expect(previous_lock_info).not_to eq(subject)
        expect(instance.locked?(key)).to be true
      end

      context 'when the lock has expired' do
        let(:prev_ttl) { 500 }

        it 'acquires a new lock' do
          sleep 1

          expect(instance.locked?(key)).to be false

          previous_lock_info = job['lock_info']
          expect(subject).to be_a(Hash)
          expect(job['lock_info']).to eq(subject)
          expect(previous_lock_info).not_to eq(subject)
          expect(instance.locked?(key)).to be true
        end
      end
    end
  end

  describe '.unlock_job' do
    subject { instance.unlock_job(job) }

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
      before { instance.lock_job_from_client!(job, key, ttl) }

      it 'unlocks the job' do
        expect(instance.locked?(key)).to be true
        expect(subject).not_to be_nil
        expect(instance.locked?(key)).to be false
      end
    end
  end
end
