class ChangeCollationForTagNames < ActiveRecord::Migration[6.0]
  def up
    if Uggle::Utils.using_mysql?
      execute("ALTER TABLE #{Uggle.tags_table} MODIFY name varchar(255) CHARACTER SET utf8 COLLATE utf8_bin;")
    end
  end
end
