# frozen_string_literal: true

require 'redis'

module RediSesh
  class Store
    DEFAULT_EXPIRES_IN = 60 * 60 * 24 # 1 day

    def self.create(url)
      uri = URI.parse(url)
      parts = uri.path.split('/')

      parts.shift if parts.first.empty?

      if parts.size > 1
        path, prefix = parts
        uri.path = "/#{path}"
      else
        prefix = 'sessions'
      end

      redis = Redis.new(url: uri)
      new(redis: redis, prefix: prefix)
    end

    def initialize(redis:, prefix:)
      @redis = redis
      @prefix = prefix
    end

    def info
      redis.info
    end

    def set(key, value, options = {})
      key = build_key(key)
      expires_in = options.fetch(:expires_in, DEFAULT_EXPIRES_IN)
      value = serialize(value)
      redis.set(key, value, ex: expires_in)
    end

    def get(key)
      data = redis.get(build_key(key))
      deserialize(data)
    end

    def del(*keys)
      redis.del(*keys.map { |key| build_key(key) })
    end

    def keys
      redis.keys("#{prefix}:*").map do |key|
        key.delete_prefix("#{prefix}:")
      end
    end

    private

    attr_reader :redis, :prefix

    def build_key(key)
      "#{prefix}:#{key}"
    end

    def serialize(data)
      Marshal.dump(data)
    end

    def deserialize(data)
      data ? Marshal.load(data) : nil
    end
  end
end
