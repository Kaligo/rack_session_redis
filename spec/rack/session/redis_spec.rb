# frozen_string_literal: true

RSpec.describe Rack::Session::Redis do
  # rubocop:disable RSpec/VerifiedDoubles
  let(:app) { double('app') }
  # rubocop:enable RSpec/VerifiedDoubles
  let(:middleware) { described_class.new(app, {}) }

  describe '#find_session' do
    context 'when session is skipped' do
      let(:session) { instance_double(Rack::Session::Abstract::SessionHash, options: { skip: true }) }
      let(:request) { instance_double(Rack::Request, session: session) }
      let(:sid) { SecureRandom.hex }

      before do
        expect(RediSesh::Store).not_to receive(:create)
      end

      it 'generates a new session id without persisting anything' do
        new_sid, new_session = middleware.find_session(request, sid)
        expect(new_session).to eq({})
        expect(new_sid).not_to eq(sid)
      end
    end

    context 'when session is not skipped but there is no existing session' do
      let(:session) { instance_double(Rack::Session::Abstract::SessionHash, options: { skip: false }) }
      let(:request) { instance_double(Rack::Request, session: session) }
      let(:redis) { MockRedis.new }
      let(:store) { RediSesh::Store.new(redis: redis, prefix: 'rack:session') }
      let(:private_id) { SecureRandom.hex }
      let(:public_id) { SecureRandom.hex }
      let(:sid) { instance_double(Rack::Session::SessionId, private_id: private_id, public_id: public_id) }

      before do
        expect(RediSesh::Store).to receive(:create)
          .with('redis://127.0.0.1:6379/0/rack:session')
          .and_return(store)
      end

      it 'generates a new session id without persisting anything' do
        new_sid, new_session = middleware.find_session(request, sid)
        expect(new_session).to eq({})
        expect(new_sid).not_to eq(sid)

        expect(redis.get("rack:session:#{new_sid.private_id}")).to be_nil
      end
    end

    context 'when session is not skipped and there is existing session' do
      let(:session) { instance_double(Rack::Session::Abstract::SessionHash, options: { skip: false }) }
      let(:request) { instance_double(Rack::Request, session: session) }
      let(:redis) { MockRedis.new }
      let(:store) { RediSesh::Store.new(redis: redis, prefix: 'rack:session') }
      let(:private_id) { SecureRandom.hex }
      let(:public_id) { SecureRandom.hex }
      let(:sid) { instance_double(Rack::Session::SessionId, private_id: private_id, public_id: public_id) }

      before do
        expect(RediSesh::Store).to receive(:create)
          .with('redis://127.0.0.1:6379/0/rack:session').and_return(store)
        store.set(private_id, { a: 1 })
      end

      it 'returns existing session' do
        expect do
          new_sid, session = middleware.find_session(request, sid)
          expect(session).to eq({ a: 1 })
          expect(new_sid).to eq(sid)
        end.not_to change { store.get(private_id) }
      end
    end
  end

  describe '#write_session' do
    let(:request) { instance_double(Rack::Request) }
    let(:redis) { MockRedis.new }
    let(:store) { RediSesh::Store.new(redis: redis, prefix: 'rack:session') }
    let(:private_id) { SecureRandom.hex }
    let(:public_id) { SecureRandom.hex }
    let(:sid) { instance_double(Rack::Session::SessionId, private_id: private_id, public_id: public_id) }

    before do
      expect(RediSesh::Store).to receive(:create)
        .with('redis://127.0.0.1:6379/0/rack:session').and_return(store)
    end

    it 'sets the session in redis' do
      expect do
        expect(middleware.write_session(request, sid, { a: 1 })).to eq(sid)
      end.to change { store.get(private_id) }.from(nil).to({ a: 1 })
    end
  end

  describe '#delete_session' do
    subject { middleware.delete_session(request, sid, options) }

    let(:request) { instance_double(Rack::Request) }
    let(:redis) { MockRedis.new }
    let(:store) { RediSesh::Store.new(redis: redis, prefix: 'rack:session') }
    let(:private_id) { SecureRandom.hex }
    let(:public_id) { SecureRandom.hex }
    let(:sid) { instance_double(Rack::Session::SessionId, private_id: private_id, public_id: public_id) }

    before do
      expect(RediSesh::Store).to receive(:create)
        .with('redis://127.0.0.1:6379/0/rack:session').and_return(store)
      store.set(private_id, { a: 1 })
    end

    context 'when options is not drop' do
      let(:options) { {} }

      it 'removes the session in redis' do
        expect do
          expect(subject).to be_a(Rack::Session::SessionId)
        end.to change { store.get(private_id) }.from({ a: 1 }).to(nil)
      end
    end

    context 'when options is drop' do
      let(:options) { { drop: true } }

      it 'removes the session in redis' do
        expect do
          expect(subject).to be_nil
        end.to change { store.get(private_id) }.from({ a: 1 }).to(nil)
      end
    end
  end

  describe '#threadsafe?' do
    subject(:middleware) { described_class.new(app, options) }

    context 'when threadsafe is not set' do
      let(:options) { {} }

      it { is_expected.to be_threadsafe }
    end

    context 'when threadsafe is set to false' do
      let(:options) { { threadsafe: false } }

      it { is_expected.not_to be_threadsafe }
    end

    context 'when threadsafe is set to true' do
      let(:options) { { threadsafe: true } }

      it { is_expected.to be_threadsafe }
    end
  end
end
