RSpec.describe SidekiqUnicity::Job do
  class TestJob
    include Sidekiq::Job

    def perform
    end
  end

  it 'adds the option methods' do
    expect(TestJob).to respond_to(:sidekiq_unicity_options)
    expect(TestJob).to respond_to(:sidekiq_unicity_lock)
  end

  context 'when settings options' do
    before { TestJob.sidekiq_unicity_options(lock: :before_processing, lock_key_proc: -> { 'test' }) }

    subject(:lock) { TestJob.sidekiq_unicity_lock }

    it { expect(lock).to be_a(SidekiqUnicity::Locks::BeforeProcessing) }
  end
end
