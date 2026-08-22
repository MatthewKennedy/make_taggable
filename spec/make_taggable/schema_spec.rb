require "spec_helper"

# The suite builds its schema by running the gem's own db/migrate files, so
# these examples describe what an application ends up with after installing
# them.
RSpec.describe "the shipped migrations" do
  let(:taggings_table) { MakeTaggable::Tagging.table_name }
  let(:indexes) { ActiveRecord::Base.connection.indexes(taggings_table) }
  let(:index_columns) { indexes.map(&:columns) }

  describe "the taggings indexes" do
    it "does not index a column another index already leads with" do
      leading_columns = index_columns.filter_map { |columns| columns.first if columns.size > 1 }

      redundant = index_columns.select { |columns| columns.size == 1 && leading_columns.include?(columns.first) }

      expect(redundant).to be_empty
    end

    it "indexes the tagger pair in one direction only" do
      tagger_pairs = index_columns.select { |columns| columns.sort == %w[tagger_id tagger_type] }

      expect(tagger_pairs).to eq([%w[tagger_id tagger_type]])
    end

    it "indexes the taggable pair in one direction only" do
      taggable_pairs = index_columns.select { |columns| columns.sort == %w[taggable_id taggable_type] }

      expect(taggable_pairs.size).to be <= 1
    end

    # The counterweight to the examples above: they are satisfied by dropping
    # every index, so name what has to survive.
    it "keeps the indexes the library's own queries need" do
      expect(index_columns).to include(
        %w[tag_id taggable_id taggable_type context tagger_id tagger_type],
        %w[taggable_id taggable_type context],
        %w[taggable_id taggable_type tagger_id context],
        %w[tagger_id tagger_type],
        %w[context]
      )
    end

    it "keeps the unique index that stops duplicate taggings" do
      expect(indexes.find { |index| index.name == "taggings_idx" }.unique).to be(true)
    end

    it "keeps the partial unique index that stops duplicate unowned taggings", if: supports_partial_indexes? do
      unowned = indexes.find { |index| index.name == "taggings_unowned_idx" }

      expect(unowned.unique).to be(true)
      expect(unowned.columns).to eq(%w[tag_id taggable_id taggable_type context])
    end
  end
end
