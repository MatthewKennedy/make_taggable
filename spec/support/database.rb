# Connects the suite to a database and builds the schema.
#
# SQLite runs in memory and needs no setup. MySQL and PostgreSQL are driven by
# DATABASE_URL, and are dropped clean on boot so a re-run never inherits state.
#
# The MakeTaggable tables are built by running the gem's own db/migrate files,
# so every suite run exercises the migrations we actually ship.

adapter = ENV.fetch("DATABASE_ADAPTER", "sqlite3")

connection_config =
  case adapter
  when "sqlite3"
    {adapter: "sqlite3", database: ":memory:"}
  else
    ENV.fetch("DATABASE_URL") do
      raise "DATABASE_URL must be set when DATABASE_ADAPTER is #{adapter}"
    end
  end

ActiveRecord::Base.establish_connection(connection_config)
ActiveRecord::Base.logger = Logger.new(IO::NULL)
ActiveRecord::Migration.verbose = false

connection = ActiveRecord::Base.connection

# Start from an empty database. In-memory SQLite is already empty; the server
# adapters keep whatever the last run left behind.
#
# `force: :cascade` is not enough on its own. MySQL parses CASCADE and ignores
# it, so dropping tags while taggings still references it fails. That the loop
# works at all today is an accident of connection.tables coming back
# alphabetically, which puts taggings first -- nothing promises that order.
# Suspending referential integrity removes the dependence on it. The method is
# a no-op on adapters that do not need it.
connection.disable_referential_integrity do
  connection.tables.each { |table| connection.drop_table(table, force: :cascade) }
end

ActiveRecord::MigrationContext.new(
  File.expand_path("../../db/migrate", __dir__)
).migrate

# Tables backing the suite's own models. These stand in for a host application,
# and are deliberately not part of the gem.
ActiveRecord::Schema.define do
  create_table :taggable_models, force: true do |t|
    t.string :name
    t.string :type
  end

  create_table :columns_override_models, force: true do |t|
    t.string :name
    t.string :type
    t.string :ignored_column
  end

  create_table :non_standard_id_taggable_models, primary_key: "an_id", force: true do |t|
    t.string :name
    t.string :type
  end

  create_table :untaggable_models, force: true do |t|
    t.integer :taggable_model_id
    t.string :name
  end

  create_table :cached_models, force: true do |t|
    t.string :name
    t.string :type
    t.string :cached_tag_list
  end

  create_table :other_cached_models, force: true do |t|
    t.string :name
    t.string :type
    t.string :cached_language_list
    t.string :cached_status_list
    t.string :cached_glass_list
  end

  create_table :cache_methods_injected_models, force: true do |t|
    t.string :cached_tag_list
  end

  create_table :companies, force: true do |t|
    t.string :name
  end

  create_table :users, force: true do |t|
    t.string :name
  end

  create_table :other_taggable_models, force: true do |t|
    t.string :name
    t.string :type
  end

  create_table :ordered_taggable_models, force: true do |t|
    t.string :name
    t.string :type
  end

  if MakeTaggable::Utils.using_postgresql?
    create_table :other_cached_with_array_models, force: true do |t|
      t.string :name
      t.string :type
      t.string :cached_language_list, array: true
      t.string :cached_status_list, array: true
      t.string :cached_glass_list, array: true
    end

    create_table :taggable_model_with_jsons, force: true do |t|
      t.string :name
      t.string :type
      t.json :opts
    end
  end
end
