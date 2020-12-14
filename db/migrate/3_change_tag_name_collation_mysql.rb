class ChangeTagNameCollationMysql < ActiveRecord::Migration[5.2]
  def change
    if MakeTaggable::Utils.using_mysql?
      execute("ALTER TABLE #{MakeTaggable.tags_table} MODIFY name varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;")
    end
  end
end
