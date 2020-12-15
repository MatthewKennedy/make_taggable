class CreateOtherCachedModels < ActiveRecord::Migration[5.2]
  def change
    create_table :other_cached_models do |t|
      t.column :name, :string
      t.column :type, :string
      t.column :cached_language_list, :string
      t.column :cached_status_list, :string
      t.column :cached_glass_list, :string
    end
  end
end
