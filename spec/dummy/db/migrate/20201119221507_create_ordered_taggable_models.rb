class CreateOrderedTaggableModels < ActiveRecord::Migration[6.0]
  def change
    create_table :ordered_taggable_models do |t|
      t.column :name, :string
      t.column :type, :string
    end
  end
end
