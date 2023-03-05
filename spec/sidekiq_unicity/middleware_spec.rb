RSpec.describe SidekiqUnicity::Middleware do
  class TestMiddlewareLockJob
    include Sidekiq::Job

    sidekiq_unicity_options lock: :before_processing, lock_key_proc: ->(_args) {}

    def perform
    end
  end

  class TestMiddlewareNoLockJob
    include Sidekiq::Job

    def perform
    end
  end

  shared_examples 'middleware behavior' do
    before { allow(middleware_instance).to receive(:with_lock).and_call_original }

    subject { middleware_instance.call(nil, { 'class' => klass }, 'default_queue', *args) { 'yield' } }

    let(:middleware_instance) { described_class.new }

    context 'with a lock' do
      let(:klass) { 'TestMiddlewareLockJob' }

      context 'with a disabled queue' do
        before { SidekiqUnicity.configure { _1.excluded_queues = ['default_queue'] } }

        it 'skips unicity' do
          expect(subject).to eq('yield')
        end
      end

      context 'with an enabled queue' do
        before { SidekiqUnicity.configure { _1.excluded_queues = nil } }

        it 'calls unicity' do
          expect(subject).to eq('yield')
          expect(middleware_instance).to have_received(:with_lock)
        end
      end
    end

    context 'without a lock' do
      let(:klass) { 'TestMiddlewareNoLockJob' }

      it 'skips unicity' do
        expect(subject).to eq('yield')
        expect(middleware_instance).not_to have_received(:with_lock)
      end
    end
  end

  describe SidekiqUnicity::Middleware::ServerMiddleware do
    let(:args) { [] }

    include_examples 'middleware behavior'
  end

  describe SidekiqUnicity::Middleware::ClientMiddleware do
    let(:args) { [nil] }

    include_examples 'middleware behavior'
  end
end
