# frozen_string_literal: true

RSpec.describe RackSessionRedis::ConnectionWrapper do
  describe '.new' do
    subject(:wrapper) { described_class.new(options) }

    let(:redis_store) { nil }
    let(:pool) { nil }
    let(:options) { { redis_store: redis_store, pool: pool } }

    context 'when pool is provided and is not a ConnectionPool' do
      let(:pool) { 'not a connection pool' }

      it 'raises an ArgumentError' do
        expect { wrapper }.to raise_error(ArgumentError, 'pool must be an instance of ConnectionPool')
      end
    end

    context 'when pool is provided and is a ConnectionPool' do
      let(:pool) { ConnectionPool.new(size: 1) { MockRedis.new } }

      it { is_expected.to be_a(described_class) }
    end

    context 'when redis_store is provided and is not a Redis::Store' do
      let(:redis_store) { 'not a redis store' }

      it 'raises an ArgumentError' do
        expect do
          wrapper
        end.to raise_error(ArgumentError, 'redis_store must be an instance of Redis::Store (currently String)')
      end
    end

    context 'when redis_store is provided and is a Redis::Store' do
      let(:redis_store) { RackSessionRedis::Store.new(redis: MockRedis.new, prefix: 'ss') }

      it { is_expected.to be_a(described_class) }
    end
  end

  describe '#with' do
    subject(:wrapper) { described_class.new(options) }

    let(:redis_store) { RackSessionRedis::Store.new(redis: MockRedis.new, prefix: 'ss') }
    let(:pool) { ConnectionPool.new(size: 1) { redis_store } }

    context 'when the wrapper is pooled' do
      let(:options) { { redis_store: nil, pool: pool } }

      it 'yields the store using connection pool' do
        expect do |b|
          wrapper.with(&b)
        end.to yield_with_args(redis_store)
      end
    end

    context 'when the wrapper is not pooled' do
      let(:options) { { redis_store: redis_store, pool: nil } }

      it 'yields the store' do
        expect do |b|
          wrapper.with(&b)
        end.to yield_with_args(redis_store)
      end
    end
  end

  describe '#pooled?' do
    subject(:wrapper) { described_class.new(options) }

    let(:redis_store) { RackSessionRedis::Store.new(redis: MockRedis.new, prefix: 'ss') }
    let(:pool) { ConnectionPool.new(size: 1) { redis_store } }

    context 'when the wrapper is pooled' do
      let(:options) { { pool: pool } }

      it { is_expected.to be_pooled }
    end

    context 'when the wrapper is not pooled' do
      let(:options) { { redis_store: redis_store } }

      it { is_expected.not_to be_pooled }
    end
  end

  describe '#pool' do
    subject { described_class.new(options).pool }

    let(:redis_store) { RackSessionRedis::Store.new(redis: MockRedis.new, prefix: 'ss') }
    let(:pool) { ConnectionPool.new(size: 1) { redis_store } }

    context 'when the wrapper is pooled' do
      let(:options) { { pool: pool } }

      it { is_expected.to eq pool }
    end

    context 'when the wrapper is not pooled' do
      let(:options) { { redis_store: redis_store } }

      it { is_expected.to be_nil }
    end

    context 'when pool options is provided' do
      let(:options) { { redis_store: redis_store, pool_size: 2, pool_timeout: 1 } }

      it { is_expected.to be_a(ConnectionPool) }
    end
  end

  describe '#store' do
    subject { described_class.new(options).store }

    let(:redis_store) { RackSessionRedis::Store.new(redis: MockRedis.new, prefix: 'ss') }

    context 'when the wrapper defines store' do
      let(:options) { { redis_store: redis_store } }

      it { is_expected.to eq redis_store }
    end

    context 'when the wrapper does not define store' do
      let(:redis_server) { 'redis://localhost:6379/0' }
      let(:options) { { redis_server: redis_server } }

      before do
        expect(RackSessionRedis::Store).to receive(:create)
          .with(redis_server).and_return(redis_store)
      end

      it { is_expected.to eq redis_store }
    end
  end

  describe '#pool_options' do
    subject { described_class.new(options).pool_options }

    let(:redis_store) { RackSessionRedis::Store.new(redis: MockRedis.new, prefix: 'ss') }
    let(:pool) { ConnectionPool.new(size: 1) { redis_store } }

    context 'when the wrapper is pooled' do
      let(:options) { { pool: pool } }

      it { is_expected.to eq({}) }
    end

    context 'when the wrapper is not pooled' do
      let(:options) { { redis_store: redis_store } }

      it { is_expected.to eq({}) }
    end

    context 'when pool options is provided' do
      let(:options) { { redis_store: redis_store, pool_size: 2, pool_timeout: 1 } }

      it { is_expected.to eq(size: 2, timeout: 1) }
    end
  end
end
