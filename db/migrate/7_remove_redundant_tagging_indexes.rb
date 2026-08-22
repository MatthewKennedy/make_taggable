class RemoveRedundantTaggingIndexes < ActiveRecord::Migration[7.2]
  # Migrations 2 and 5 between them put twelve indexes on the taggings table.
  # Five of them earn nothing: a B-tree index already answers any query that
  # filters on a leading subset of its columns, so an index on a single column
  # is dead weight whenever another index starts with that same column.
  #
  #   tag_id        -> covered by taggings_idx and taggings_unowned_idx
  #   taggable_id   -> covered by taggings_taggable_context_idx and taggings_idy
  #   taggable_type -> covered by index_taggings_on_taggable_type_and_taggable_id
  #   tagger_id     -> covered by index_taggings_on_tagger_id_and_tagger_type
  #
  # The fifth is the tagger pair, which migration 2 and migration 5 each added
  # in opposite column orders. One of the two is enough; the order kept is the
  # one the library's own queries filter in, tagger_id first.
  #
  # Every index is maintained on insert, so this is a write-cost and a
  # disk-footprint change, not a query-plan one. Nothing here is load-bearing:
  # each dropped index is a prefix of one that remains.
  REDUNDANT_COLUMNS = [
    [:tag_id],
    [:taggable_id],
    [:taggable_type],
    [:tagger_id],
    [:tagger_type, :tagger_id]
  ].freeze

  def up
    REDUNDANT_COLUMNS.each do |columns|
      remove_index MakeTaggable.taggings_table, column: columns if index_exists?(MakeTaggable.taggings_table, columns)
    end
  end

  def down
    REDUNDANT_COLUMNS.each do |columns|
      add_index MakeTaggable.taggings_table, columns unless index_exists?(MakeTaggable.taggings_table, columns)
    end
  end
end
