require "spec_helper"

RSpec.describe MakeTaggable::Utils do
  describe "#like_operator" do
    it "should return 'ILIKE' when the adapter is PostgreSQL" do
      allow(MakeTaggable::Utils.connection).to receive(:adapter_name) { "PostgreSQL" }
      expect(MakeTaggable::Utils.like_operator).to eq("ILIKE")
    end

    it "should return 'LIKE' when the adapter is not PostgreSQL" do
      allow(MakeTaggable::Utils.connection).to receive(:adapter_name) { "MySQL" }
      expect(MakeTaggable::Utils.like_operator).to eq("LIKE")
    end
  end

  describe "#using_postgresql?" do
    it "is true when the adapter is PostgreSQL" do
      allow(MakeTaggable::Utils.connection).to receive(:adapter_name) { "PostgreSQL" }
      expect(MakeTaggable::Utils.using_postgresql?).to be(true)
    end

    it "is true when the adapter is PostGIS, which is PostgreSQL underneath" do
      allow(MakeTaggable::Utils.connection).to receive(:adapter_name) { "PostGIS" }
      expect(MakeTaggable::Utils.using_postgresql?).to be(true)
    end

    it "is false for any other adapter" do
      allow(MakeTaggable::Utils.connection).to receive(:adapter_name) { "SQLite" }
      expect(MakeTaggable::Utils.using_postgresql?).to be(false)
    end
  end

  describe "#like_operator with PostGIS" do
    it "returns 'ILIKE', so a PostGIS app gets case-insensitive matching" do
      allow(MakeTaggable::Utils.connection).to receive(:adapter_name) { "PostGIS" }
      expect(MakeTaggable::Utils.like_operator).to eq("ILIKE")
    end
  end

  describe "#sha_prefix" do
    it "should return a consistent prefix for a given word" do
      expect(MakeTaggable::Utils.sha_prefix("kittens")).to eq(MakeTaggable::Utils.sha_prefix("kittens"))
      expect(MakeTaggable::Utils.sha_prefix("puppies")).not_to eq(MakeTaggable::Utils.sha_prefix("kittens"))
    end
  end
end
