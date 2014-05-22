require_relative '../lib/bosh_mediator_factory'

module BoshMediator
  describe 'Bosh Mediator Factory' do

    let(:assets_dir) { File.expand_path(File.dirname(__FILE__)) + "/assets" }
    let(:bmf) { Object.new.extend(BoshMediatorFactory) }

    describe '#create_bosh_mediator' do
      it 'can be instantiated with a URI, credentials, release manifest and release directory' do
        mediator = bmf.create_bosh_mediator(
          'http://localhost:25555', 'username', 'password', assets_dir)
        expect(mediator).to respond_to(:deploy)
      end
      it 'raises if the release directory does not exist' do
        expect do
          bmf.create_bosh_mediator('http://localhost:25555', 'username', 'password', '/does-not-exist')
        end.to raise_error(ArgumentError, 'Release directory does not exist: /does-not-exist')
      end
    end
    describe '#create_local_bosh_mediator' do
      it 'can be instantiated without needing Director information ' do
        mediator = bmf.create_local_bosh_mediator(assets_dir)
        expect(mediator).to respond_to(:deploy)
      end
      it 'raises if the release directory does not exist' do
        expect do
          bmf.create_local_bosh_mediator('/does-not-exist')
        end.to raise_error(ArgumentError, 'Release directory does not exist: /does-not-exist')
      end
    end

  end
end
