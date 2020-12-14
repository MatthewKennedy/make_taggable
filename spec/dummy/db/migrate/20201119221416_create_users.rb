class CreateUsers < ActiveRecord::Migration[4.2]
  def change
    create_table :users do |t|
      t.column :name, :string
    end
  end
end
