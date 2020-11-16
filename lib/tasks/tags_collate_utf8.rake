# These rake tasks are to be run by MySql users only, they fix the management of
# binary-encoded strings for tag 'names'. Issues:
# https://github.com/mbleigh/acts-as-taggable-on/issues/623

namespace :uggle_engine do
  namespace :tag_names do
    desc "Forcing collate of tag names to utf8_bin"
    task :collate_bin => [:environment] do |t, args|
      Uggle::Configuration.apply_binary_collation(true)
    end

    desc "Forcing collate of tag names to utf8_general_ci"
    task :collate_ci => [:environment] do |t, args|
      Uggle::Configuration.apply_binary_collation(false)
    end
  end
end
