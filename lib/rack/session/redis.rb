# frozen_string_literal: true

require 'English'
require 'rack/session/abstract/id'
require_relative '../../redi_sesh/connection_wrapper'
require_relative '../../redi_sesh/store'

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
        @conn = RediSesh::ConnectionWrapper.new(@default_options)
      end

      def find_session(req, sid)
        if req.session.options[:skip]
          [generate_sid, {}]
        else
          with_lock(req, [nil, {}]) do
            if sid && (session = get_session_with_fallback(sid))
              [sid, session]
            else
              [generate_sid, {}]
            end
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

      private

      def get_session_with_fallback(sid)
        with { |c| c.get(sid.private_id) || c.get(sid.public_id) }
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
    end
  end
end
