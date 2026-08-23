require "spec_helper"

# tag_list reads like an attribute and is not one. These examples pin the
# consequences of that: what belongs in the attribute set, and what the dirty
# API has to keep doing without it.
RSpec.describe "Tag lists and the attribute set" do
  def count_queries
    queries = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      queries += 1 unless payload[:name].to_s.match?(/SCHEMA|TRANSACTION/)
    end
    yield
    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  before do
    3.times { |i| TaggableModel.create!(name: "r#{i}", tag_list: "ruby") }
  end

  describe "the attribute set" do
    it "does not carry the tag list" do
      record = TaggableModel.first

      expect(record.attributes).not_to have_key("tag_list")
    end
  end

  describe "serialising" do
    it "leaves the tag list out of as_json" do
      expect(TaggableModel.first.as_json).not_to have_key("tag_list")
    end

    it "does not query for tags while serialising a collection" do
      records = TaggableModel.limit(3).to_a

      expect(count_queries { records.as_json }).to eq(0)
    end

    it "still serialises the tag list when asked for it" do
      record = TaggableModel.first

      expect(record.as_json(methods: :tag_list)["tag_list"]).to eq(["ruby"])
    end
  end

  describe "tag_ids" do
    it "can clear the tags after as_json has been called" do
      record = TaggableModel.first
      record.as_json

      record.tag_ids = []
      record.save

      expect(record.reload.tag_list.to_a).to eq([])
    end
  end

  describe "upsert_all" do
    it "writes the real columns" do
      expect {
        TaggableModel.upsert_all([{name: "upserted"}])
      }.to change { TaggableModel.where(name: "upserted").count }.by(1)
    end

    # upsert_all writes columns straight to the database, and a tag list is not
    # a column -- applying one means writing taggings, which it cannot do. So
    # refusing is right. It is named here because as_json used to put tag_list
    # into the hash, which made round-tripping as_json output back through
    # upsert_all fail for a reason that had nothing to do with the caller.
    it "refuses a tag list, which as_json no longer puts there" do
      expect {
        TaggableModel.upsert_all([{name: "upserted", tag_list: "x"}])
      }.to raise_error(ActiveModel::UnknownAttributeError)
    end

    it "round-trips as_json output" do
      row = TaggableModel.first.as_json.except("id")

      expect { TaggableModel.upsert_all([row]) }.not_to raise_error
    end
  end
end
