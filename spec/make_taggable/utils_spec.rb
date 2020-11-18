require "spec_helper"

describe MakeTaggable::Utils do
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

  describe "#sha_prefix" do
    it "should return a consistent prefix for a given word" do
      expect(MakeTaggable::Utils.sha_prefix("kittens")).to eq(MakeTaggable::Utils.sha_prefix("kittens"))
      expect(MakeTaggable::Utils.sha_prefix("puppies")).not_to eq(MakeTaggable::Utils.sha_prefix("kittens"))
    end
  end
end
