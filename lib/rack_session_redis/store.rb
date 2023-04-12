module RackSessionRedis
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
      if keys.any?
        redis.del(*keys.map { |key| build_key(key) })
      end
    end

    def keys
      redis.keys.map do |key|
        key.delete_prefix("#{prefix}:")
      end
    end

    def mset(*args)
      options = args.length.odd? ? args.pop : {}
      expires_in = options.fetch(:expires_in, DEFAULT_EXPIRES_IN)

      data = args.each_slice(2).flat_map do |key, value|
        [build_key(key), serialize(value)]
      end
      redis.set(*data, ex: expires_in)
    end

    def mget(*keys)
      keys = keys.map { |key| build_key(key) }
      redis.mget(*keys).map { |data| deserialize(data) }
    end

    def getdel(*keys)
      keys = keys.map { |key| build_key(key) }
      data = []

      redis.multi do |transaction|
        data = transaction.mget(*keys)
        transaction.del(*keys)
      end

      data.value.map { |item| deserialize(item) }
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
