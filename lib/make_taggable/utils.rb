# frozen_string_literal: true

module MakeTaggable
  ##
  # Database differences the rest of the library needs to work around.
  #
  module Utils
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
      # @return [TrueClass, FalseClass]
      #
      def using_postgresql?
        connection && connection.adapter_name == "PostgreSQL"
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
      # @return [String] `"ILIKE"` on PostgreSQL, otherwise `"LIKE"`
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
