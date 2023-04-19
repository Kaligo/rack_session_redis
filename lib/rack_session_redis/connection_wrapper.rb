# frozen_string_literal: true

module RackSessionRedis
  class ConnectionWrapper
    POOL_KEYS = %i[pool pool_size pool_timeout].freeze

    def initialize(options = {})
      @options = options
      @store = options[:redis_store]
      @pool = options[:pool]

      raise ArgumentError, 'pool must be an instance of ConnectionPool' if @pool && !@pool.is_a?(ConnectionPool)

      return unless @store && !@store.is_a?(RackSessionRedis::Store)

      raise ArgumentError, "redis_store must be an instance of RackSessionRedis::Store (currently #{@store.class.name})"
    end

    def with(&block)
      if pooled?
        pool.with(&block)
      else
        block.call(store)
      end
    end

    def pooled?
      return @pooled if defined?(@pooled)

      @pooled = POOL_KEYS.any? { |key| @options.key?(key) }
    end

    def pool
      @pool ||= ConnectionPool.new(pool_options) { store } if pooled?
    end

    def store
      @store ||= Store.create(@options[:redis_server])
    end

    def pool_options
      {
        size: @options[:pool_size],
        timeout: @options[:pool_timeout]
      }.compact.to_h
    end
  end
end
