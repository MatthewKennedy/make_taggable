# frozen_string_literal: true

module MakeTaggable
  ##
  # Database differences the rest of the library needs to work around.
  #
  module Utils
    ##
    # Adapter names that are PostgreSQL as far as SQL generation is concerned.
    #
    # PostGIS is the PostgreSQL adapter with spatial types layered on top. It reports its own
    # adapter name, so it has to be named here or the library treats a PostGIS application as
    # though it were on MySQL -- `LIKE` in place of `ILIKE`, and the wrong grouping strategy.
    #
    # @return [Array<String>] frozen
    #
    POSTGRESQL_ADAPTER_NAMES = %w[PostgreSQL PostGIS].freeze

    class << self
      ##
      # The connection tags are read and written through.
      #
      # @return [ActiveRecord::ConnectionAdapters::AbstractAdapter]
      #
      def connection
        MakeTaggable::Tag.connection
      end

      ##
      # Whether tags are stored in PostgreSQL.
      #
      # True for PostGIS as well, which is PostgreSQL underneath.
      #
      # @return [TrueClass, FalseClass]
      #
      def using_postgresql?
        !!connection && POSTGRESQL_ADAPTER_NAMES.include?(connection.adapter_name)
      end

      ##
      # Whether tags are stored in MySQL.
      #
      # @return [TrueClass, FalseClass]
      #
      def using_mysql?
        connection && connection.adapter_name == "Mysql2"
      end

      ##
      # A short digest of a string, used to keep generated SQL aliases unique and within the
      # identifier length databases allow.
      #
      # @param string [String] the value to digest
      # @return [String] the first seven characters of the SHA1 hex digest
      #
      def sha_prefix(string)
        Digest::SHA1.hexdigest(string)[0..6]
      end

      ##
      # The case-insensitive pattern operator for the current adapter.
      #
      # @return [String] `"ILIKE"` on PostgreSQL and PostGIS, otherwise `"LIKE"`
      #
      def like_operator
        using_postgresql? ? "ILIKE" : "LIKE"
      end

      ##
      # Escapes the SQL pattern wildcards in a string so it matches literally.
      #
      # Pair it with an `ESCAPE '!'` clause.
      #
      # @param str [String] the value to escape
      # @return [String] with `!`, `%` and `_` escaped
      #
      def escape_like(str)
        str.gsub(/[!%_]/) { |x| "!" + x }
      end
    end
  end
end
