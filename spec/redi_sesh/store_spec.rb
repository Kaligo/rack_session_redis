# frozen_string_literal: true

RSpec.describe RediSesh::Store do
  let(:redis) { MockRedis.new }
  let(:store) { described_class.new(redis: redis, prefix: 'rack_session') }

  describe '.create' do
    subject { described_class.create(url) }

    let(:store) { instance_double(described_class) }

    context 'when URL does not contain namespace' do
      let(:url) { 'redis://localhost:6379/0' }

      before do
        expect(Redis).to receive(:new).with(url: URI(url)).and_return(redis)
      end

      it 'creates store using default namespace' do
        expect(described_class).to receive(:new)
          .with(redis: redis, prefix: 'sessions').and_return(store)
        expect(subject).to eq store
      end
    end

    context 'when URL contains namespace' do
      let(:url) { 'redis://localhost:6379/0/rack_session' }

      before do
        expect(Redis).to receive(:new)
          .with(url: URI('redis://localhost:6379/0')).and_return(redis)
      end

      it 'creates store with specified namespace' do
        expect(described_class).to receive(:new)
          .with(redis: redis, prefix: 'rack_session').and_return(store)
        expect(subject).to eq store
      end
    end
  end

  describe '#info' do
    subject { store.info }

    it { is_expected.to be_a(Hash) }
  end

  describe '#set' do
    let(:data) { Marshal.dump({ a: 1 }) }

    context 'when options is not provided' do
      subject { store.set('key', { a: 1 }) }

      it 'sets the value correctly' do
        expect do
          subject
        end.to change { redis.get('rack_session:key') }.from(nil).to(data)

        expires_in = described_class::DEFAULT_EXPIRES_IN
        expect(redis.ttl('rack_session:key')).to be_between(expires_in - 10, expires_in)
      end
    end

    context 'when options is provided' do
      subject { store.set('key', { a: 1 }, { expires_in: expires_in }) }

      let(:expires_in) { 3600 }

      it 'sets the value correctly' do
        expect do
          subject
        end.to change { redis.get('rack_session:key') }.from(nil).to(data)

        expect(redis.ttl('rack_session:key')).to be_between(expires_in - 10, expires_in)
      end
    end
  end

  describe '#get' do
    let(:data) { Marshal.dump({ a: 1 }) }

    context 'when key exists' do
      subject { store.get('key') }

      before do
        redis.set('rack_session:key', data)
      end

      it { is_expected.to eq({ a: 1 }) }
    end

    context 'when key does not exist' do
      subject { store.get('key') }

      it { is_expected.to be_nil }
    end
  end

  describe '#del' do
    let(:data) { Marshal.dump({ a: 1 }) }

    context 'when one key is provided' do
      subject { store.del('key_1') }

      before do
        redis.set('rack_session:key_1', data)
        redis.set('rack_session:key_2', data)
      end

      it 'deletes the key' do
        expect do
          subject
        end.to change { redis.get('rack_session:key_1') }.from(data).to(nil)

        expect(redis.get('rack_session:key_2')).to eq(data)
      end
    end

    context 'when keys are provided' do
      subject { store.del('key1', 'key2') }

      before do
        redis.set('rack_session:key1', data)
        redis.set('rack_session:key2', data)
      end

      it 'deletes the keys' do
        expect do
          subject
        end.to change {
          redis.get('rack_session:key1')
        }.from(data).to(nil).and change {
          redis.get('rack_session:key2')
        }.from(data).to(nil)
      end
    end
  end

  describe '#keys' do
    context 'when keys exist' do
      subject { store.keys }

      before do
        redis.set('rack_session:key1', Marshal.dump({ a: 1 }))
        redis.set('rack_session:key2', Marshal.dump({ a: 2 }))
      end

      it { is_expected.to eq(%w[key1 key2]) }
    end

    context 'when keys do not exist' do
      subject { store.keys }

      it { is_expected.to eq([]) }
    end
  end
end
