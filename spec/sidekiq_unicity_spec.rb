RSpec.describe SidekiqUnicity do
  it "has a version number" do
    expect(SidekiqUnicity::VERSION).not_to be nil
  end

  describe ".configure" do
    subject(:config) { described_class.configure }

    it { expect(config).to be_a(described_class::Config) }

    context 'with a Sidekiq server' do
      before { allow(Sidekiq).to receive(:server?).and_return(true) }

      it 'registers the middleware' do
        config
        expect(Sidekiq.default_configuration.client_middleware.exists?(described_class::Middleware::ClientMiddleware)).to be true
        expect(Sidekiq.default_configuration.server_middleware.exists?(described_class::Middleware::ServerMiddleware)).to be true
      end
    end
  end
end
