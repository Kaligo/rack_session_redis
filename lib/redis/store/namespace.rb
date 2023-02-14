class Redis
  class Store < self
    module Namespace
      FLUSHDB_BATCH_SIZE = 1000

      def set(key, *args)
        namespace(key) { |k| super(k, *args) }
      end

      def setex(key, *args)
        namespace(key) { |k| super(k, *args) }
      end

      def setnx(key, *args)
        namespace(key) { |k| super(k, *args) }
      end

      def ttl(key, _options = nil)
        namespace(key) { |k| super(k) }
      end

      def get(key, *args)
        namespace(key) { |k| super(k, *args) }
      end

      def keys(pattern = '*')
        namespace(pattern) { |p| super(p).map { |key| strip_namespace(key) } }
      end

      def del(*keys)
        super(*keys.map { |key| interpolate(key) }) if keys.any?
      end

      def mget(*keys, &blk)
        options = (keys.pop if keys.last.is_a? Hash) || {}
        if keys.any?
          # Serialization gets extended before Namespace does, so we need to pass options further
          if singleton_class.ancestors.include? Serialization
            super(*keys.map { |key| interpolate(key) }, options, &blk)
          else
            super(*keys.map { |key| interpolate(key) }, &blk)
          end
        end
      end

      if respond_to?(:ruby2_keywords, true)
        ruby2_keywords :set, :setex, :setnx
      end

      def to_s
        if namespace_str
          "#{super} with namespace #{namespace_str}"
        else
          super
        end
      end

      def flushdb
        return super unless namespace_str

        keys.each_slice(FLUSHDB_BATCH_SIZE) { |key_slice| del(*key_slice) }
      end

      def with_namespace(ns)
        old_ns = @namespace
        @namespace = ns
        yield self
      ensure
        @namespace = old_ns
      end

      private

      def namespace(key)
        yield interpolate(key)
      end

      def namespace_str
        @namespace.is_a?(Proc) ? @namespace.call : @namespace
      end

      def interpolate(key)
        return key unless namespace_str

        key.match(namespace_regexp) ? key : "#{namespace_str}:#{key}"
      end

      def strip_namespace(key)
        return key unless namespace_str

        key.gsub namespace_regexp, ''
      end

      def namespace_regexp
        @namespace_regexps ||= {}
        @namespace_regexps[namespace_str] ||= /^#{namespace_str}:/
      end
    end
  end
end
