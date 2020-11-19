class CreateCacheMethodsInjectedModels < ActiveRecord::Migration[6.0]
  def change
    create_table :cache_methods_injected_models do |t|
      t.column :cached_tag_list, :string
    end
  end
end
