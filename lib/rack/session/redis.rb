# frozen_string_literal: true

require 'English'
require 'rack/session/abstract/id'
require_relative '../../rack_session_redis/connection_wrapper'
require_relative '../../rack_session_redis/store'

module Rack
  module Session
    class Redis < Abstract::PersistedSecure
      attr_reader :mutex

      DEFAULT_OPTIONS = Abstract::ID::DEFAULT_OPTIONS.merge(
        redis_server: 'redis://127.0.0.1:6379/0/rack:session'
      )

      def initialize(app, options = {})
        super

        @mutex = Mutex.new
        @conn = RackSessionRedis::ConnectionWrapper.new(@default_options)
      end

      def generate_unique_sid(session)
        return generate_sid if session.empty?

        loop do
          sid = generate_sid
          first = with do |c|
            [*c.setnx(sid.private_id, session, @default_options.to_hash)].first
          end
          break sid if [1, true].include?(first)
        end
      end

      def find_session(req, sid)
        if req.session.options[:skip]
          [generate_sid, {}]
        else
          with_lock(req, [nil, {}]) do
            unless sid && (session = get_session_with_fallback(sid))
              session = {}
              sid = generate_unique_sid(session)
            end
            [sid, session]
          end
        end
      end

      def write_session(req, sid, new_session, options = {})
        with_lock(req, false) do
          with { |c| c.set(sid.private_id, new_session, options.to_hash) }
          sid
        end
      end

      def delete_session(req, sid, options)
        with_lock(req) do
          with do |c|
            c.del(sid.public_id)
            c.del(sid.private_id)
          end
          generate_sid unless options[:drop]
        end
      end

      def threadsafe?
        @default_options.fetch(:threadsafe, true)
      end

      def with_lock(_req, default = nil)
        @mutex.lock if threadsafe?
        yield
      rescue Errno::ECONNREFUSED
        if $VERBOSE
          warn "#{self} is unable to find Redis server."
          warn $ERROR_INFO.inspect
        end
        default
      ensure
        @mutex.unlock if @mutex.locked?
      end

      def with(&block)
        @conn.with(&block)
      end

      private

      def get_session_with_fallback(sid)
        with { |c| c.get(sid.private_id) || c.get(sid.public_id) }
      end
    end
  end
end
