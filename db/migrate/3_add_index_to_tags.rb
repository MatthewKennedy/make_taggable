class AddIndexToTags < ActiveRecord::Migration[4.2]
  def self.up
    add_index MakeTaggable.tags_table, :name, unique: true
  end

  def self.down
    remove_index MakeTaggable.tags_table, :name
  end
end
