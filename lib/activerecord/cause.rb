require "active_record"

require "activerecord/cause/version"

module ActiveRecord
  module Cause
    include ActiveSupport::Configurable

    config_accessor :match_paths, instance_accessor: false do
      []
    end

    class LogSubscriber < ActiveSupport::LogSubscriber
      IGNORE_PAYLOAD_NAMES = ["SCHEMA", "EXPLAIN"]

      def initialize
        super
        @odd = false
      end

      def sql(event)
        return if ActiveRecord::Cause.match_paths.empty?
        return unless logger.debug?

        payload = event.payload

        return if IGNORE_PAYLOAD_NAMES.include?(payload[:name])

        loc = caller_locations.find do |l|
          ActiveRecord::Cause.match_paths.any? do |re|
            re.match(l.absolute_path)
          end
        end

        return unless loc

        name  = "ActiveRecord::Cause"
        sql   = payload[:sql]
        binds = nil

        unless (payload[:binds] || []).empty?
          binds = "  " + payload[:binds].map { |col,v|
            render_bind(col, v)
          }.inspect
        end

        if odd?
          name = color(name, CYAN, true)
          sql  = color(sql, nil, true)
        else
          name = color(name, MAGENTA, true)
        end
        cause = color(loc.to_s, nil, true)

        debug "  #{name}  #{sql}#{binds} caused by #{cause}"
      end

      def odd?
        @odd = !@odd
      end

      def logger
        ActiveRecord::Base.logger
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::Cause::LogSubscriber.attach_to :active_record
end
