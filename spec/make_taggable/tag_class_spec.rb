require "spec_helper"

RSpec.describe "MakeTaggable.tag_class" do
  # The associations are built when make_taggable runs, so a model has to be
  # declared after the setting is in place -- which is the same ordering an
  # application gets from an initializer.
  def taggable_class_using(tag_class)
    MakeTaggable.tag_class = tag_class

    Class.new(ActiveRecord::Base) do
      self.table_name = "taggable_models"
      def self.name = "CustomTagged"
      make_taggable
    end
  end

  describe "by default" do
    it "is MakeTaggable::Tag" do
      expect(MakeTaggable.tag_class).to eq("MakeTaggable::Tag")
    end

    it "reads and writes MakeTaggable::Tag" do
      record = TaggableModel.create!(name: "Bob", tag_list: "ruby")

      expect(record.tags.first).to be_an_instance_of(MakeTaggable::Tag)
    end
  end

  describe "when set to an application's own class" do
    let(:model) { taggable_class_using("CustomTag") }

    it "creates tags of that class" do
      model.create!(name: "Bob", tag_list: "ruby")

      expect(MakeTaggable::Tag.find_by(name: "ruby")).to be_a(MakeTaggable::Tag)
      expect(CustomTag.find_by(name: "ruby")).to be_an_instance_of(CustomTag)
    end

    it "returns that class from the tags association" do
      record = model.create!(name: "Bob", tag_list: "ruby")

      expect(record.tags.first).to be_an_instance_of(CustomTag)
      expect(record.tags.first.shouty_name).to eq("RUBY")
    end

    it "returns that class from all_tags" do
      model.create!(name: "Bob", tag_list: "ruby")

      expect(model.all_tags.first).to be_an_instance_of(CustomTag)
    end

    it "returns that class from tag_counts_on" do
      model.create!(name: "Bob", tag_list: "ruby")

      expect(model.tag_counts_on(:tags).first).to be_an_instance_of(CustomTag)
    end

    it "leaves tag lists working as they are" do
      record = model.create!(name: "Bob", tag_list: "ruby, rails")

      expect(record.tag_list.to_a.sort).to eq(%w[rails ruby])
      expect(model.tagged_with("ruby").to_a).to eq([record])
    end
  end

  # MakeTaggable::Tagging declares belongs_to :tag once, when it is first loaded, so its class_name
  # is fixed before any example here runs. That path is only exercisable from a fresh process, which
  # is what an initializer gives an application -- so it is checked in one.
  describe "when set before anything loads, as an initializer does" do
    it "reaches the tagging association too" do
      script = <<~RUBY
        $LOAD_PATH.unshift "lib"
        require "active_record"
        require "logger"
        require "make_taggable"

        MakeTaggable.setup { |config| config.tag_class = "AppTag" }

        require "./spec/support/database"
        class AppTag < MakeTaggable::Tag; end
        class Article < ActiveRecord::Base
          self.table_name = "taggable_models"
          make_taggable
        end

        Article.create!(name: "a", tag_list: "ruby")
        puts MakeTaggable::Tagging.reflect_on_association(:tag).class_name
        puts MakeTaggable::Tagging.first.tag.class
      RUBY

      # In-memory SQLite, explicitly. The child runs spec/support/database.rb,
      # which drops every table before rebuilding the schema -- inheriting
      # DATABASE_URL would point that at the server database this suite is
      # using and wipe it mid-run.
      env = {"DATABASE_ADAPTER" => "sqlite3", "DATABASE_URL" => nil}

      output = IO.popen(env, [RbConfig.ruby, "-e", script], unsetenv_others: false, err: :out, &:read)

      expect(output.split("\n").last(2)).to eq(%w[AppTag AppTag])
    end
  end

  describe "validation of the setting" do
    it "rejects a class constant, which Zeitwerk cannot resolve at boot" do
      expect { MakeTaggable.tag_class = CustomTag }
        .to raise_error(ArgumentError, /String/)
    end

    it "accepts a String" do
      expect { MakeTaggable.tag_class = "CustomTag" }.not_to raise_error
    end
  end
end
