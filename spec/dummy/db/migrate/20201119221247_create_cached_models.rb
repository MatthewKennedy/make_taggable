class CreateCachedModels < ActiveRecord::Migration[6.0]
  def change
    create_table :cached_models do |t|
      t.column :name, :string
      t.column :type, :string
      t.column :cached_tag_list, :string
    end
  end
end
