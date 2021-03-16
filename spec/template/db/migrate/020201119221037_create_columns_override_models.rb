class CreateColumnsOverrideModels < ActiveRecord::Migration[5.2]
  def change
    create_table :columns_override_models do |t|
      t.column :name, :string
      t.column :type, :string
      t.column :ignored_column, :string
    end
  end
end
