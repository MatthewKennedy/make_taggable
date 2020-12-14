class CreateCachedModels < ActiveRecord::Migration[5.2]
  def change
    create_table :cached_models do |t|
      t.column :name, :string
      t.column :type, :string
      t.column :cached_tag_list, :string, limit: 128
    end
  end
end
