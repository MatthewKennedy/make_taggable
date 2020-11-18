class ChangeCollationForTagNames < ActiveRecord::Migration[4.2]
  def up
    if MakeTaggable::Utils.using_mysql?
      execute("ALTER TABLE #{MakeTaggable.tags_table} MODIFY name varchar(255) CHARACTER SET utf8 COLLATE utf8_bin;")
    end
  end
end
