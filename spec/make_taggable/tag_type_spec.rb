require "spec_helper"

# Per-context vocabularies work through single table inheritance: a `type`
# column on tags and a Tag subclass per vocabulary.
#
# These run in a subprocess. The column has to exist before anything reads the
# schema, and adding it inside the suite means DDL in the middle of a run --
# which commits implicitly on MySQL, and leaves STI subclasses holding column
# caches that no longer match the table. A fresh process is what an application
# has anyway.
RSpec.describe "Tag subclasses sharing the tags table" do
  def run_in_process(body)
    script = <<~RUBY
      $LOAD_PATH.unshift "lib"
      require "active_record"
      require "logger"
      require "make_taggable"
      require "./spec/support/database"

      ActiveRecord::Migration.suppress_messages do
        ActiveRecord::Migration.add_column :tags, :type, :string
        ActiveRecord::Migration.remove_index :tags, :name
        ActiveRecord::Migration.add_index :tags, [:name, :type], unique: true
      end

      class Market < MakeTaggable::Tag; end
      class Genre < MakeTaggable::Tag; end

      class Company < ActiveRecord::Base
        self.table_name = "companies"
        make_taggable :markets, :genres

        private

        def find_or_create_tags_from_list_with_context(tag_list, context)
          case context.to_sym
          when :markets then Market.find_or_create_all_with_like_by_name(tag_list)
          when :genres then Genre.find_or_create_all_with_like_by_name(tag_list)
          else super
          end
        end
      end

      #{body}
    RUBY

    env = {"DATABASE_ADAPTER" => "sqlite3", "DATABASE_URL" => nil}
    IO.popen(env, [RbConfig.ruby, "-e", script], unsetenv_others: false, err: :out, &:read).strip
  end

  it "lets two subclasses hold the same name" do
    output = run_in_process(<<~RUBY)
      Market.create!(name: "energy")
      Genre.create!(name: "energy")
      puts MakeTaggable::Tag.order(:id).pluck(:name, :type).inspect
    RUBY

    expect(output.lines.last).to eq('[["energy", "Market"], ["energy", "Genre"]]')
  end

  it "still rejects a duplicate within one subclass" do
    output = run_in_process(<<~RUBY)
      Market.create!(name: "energy")
      duplicate = Market.new(name: "energy")
      puts duplicate.valid?
      puts duplicate.errors[:name].inspect
    RUBY

    expect(output.lines.last(2).map(&:strip)).to eq(["false", '["has already been taken"]'])
  end

  it "scopes each subclass to its own rows" do
    output = run_in_process(<<~RUBY)
      Market.create!(name: "energy")
      Genre.create!(name: "energy")
      puts [Market.count, Genre.count, MakeTaggable::Tag.count].inspect
    RUBY

    expect(output.lines.last).to eq("[1, 1, 2]")
  end

  it "keeps the vocabularies apart on a taggable" do
    output = run_in_process(<<~RUBY)
      company = Company.create!(name: "Acme", market_list: "energy", genre_list: "energy")
      company.reload
      puts [company.market_list.to_a, company.genre_list.to_a, company.markets.map { |t| t.class.name }].inspect
    RUBY

    expect(output.lines.last).to eq('[["energy"], ["energy"], ["Market"]]')
  end

  it "finds a taggable by a tag in one vocabulary" do
    output = run_in_process(<<~RUBY)
      Company.create!(name: "Acme", market_list: "energy")
      Company.create!(name: "Other", genre_list: "energy")
      puts Company.tagged_with("energy", on: :markets).pluck(:name).inspect
    RUBY

    expect(output.lines.last).to eq('["Acme"]')
  end
end

RSpec.describe "Tag name uniqueness without a type column" do
  it "rejects a duplicate name across the whole table" do
    MakeTaggable::Tag.create!(name: "energy")

    expect(MakeTaggable::Tag.new(name: "energy")).not_to be_valid
  end
end
