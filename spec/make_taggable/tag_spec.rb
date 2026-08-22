require "spec_helper"

RSpec.describe MakeTaggable::Tag do
  around do |example|
    strict_case_match = MakeTaggable.strict_case_match
    example.run
  ensure
    MakeTaggable.strict_case_match = strict_case_match
  end

  describe "validations" do
    it "requires a name" do
      expect(described_class.new(name: nil)).not_to be_valid
    end

    it "accepts a name of 255 characters" do
      expect(described_class.new(name: "a" * 255)).to be_valid
    end

    it "rejects a name longer than 255 characters" do
      expect(described_class.new(name: "a" * 256)).not_to be_valid
    end

    it "rejects a name already taken" do
      described_class.create!(name: "ruby")

      expect(described_class.new(name: "ruby")).not_to be_valid
    end

    it "accepts a name differing only in case" do
      described_class.create!(name: "ruby")

      expect(described_class.new(name: "Ruby")).to be_valid
    end

    it "skips the uniqueness check when validates_name_uniqueness? is false" do
      subclass = Class.new(described_class) do
        def validates_name_uniqueness?
          false
        end
      end
      stub_const("PermissiveTag", subclass)
      described_class.create!(name: "ruby")

      expect(PermissiveTag.new(name: "ruby")).to be_valid
    end
  end

  describe ".named" do
    it "finds a tag by an exact name" do
      described_class.create!(name: "ruby")

      expect(described_class.named("ruby").map(&:name)).to eq(["ruby"])
    end

    it "ignores case by default" do
      described_class.create!(name: "Ruby")

      expect(described_class.named("ruby").map(&:name)).to eq(["Ruby"])
    end

    it "respects case when strict_case_match is on" do
      described_class.create!(name: "Ruby")
      MakeTaggable.strict_case_match = true

      expect(described_class.named("ruby")).to be_empty
    end

    it "finds a tag whose name is not ASCII" do
      described_class.create!(name: "привет")

      expect(described_class.named("привет").map(&:name)).to eq(["привет"])
    end
  end

  describe ".named_any" do
    it "finds every tag in the list" do
      described_class.create!(name: "ruby")
      described_class.create!(name: "rails")

      expect(described_class.named_any(%w[ruby rails]).map(&:name)).to match_array(%w[ruby rails])
    end

    it "ignores names that do not exist" do
      described_class.create!(name: "ruby")

      expect(described_class.named_any(%w[ruby nope]).map(&:name)).to eq(["ruby"])
    end

    it "ignores case by default" do
      described_class.create!(name: "Ruby")

      expect(described_class.named_any(["ruby"]).map(&:name)).to eq(["Ruby"])
    end

    # Regression: sanitised SQL was forced to BINARY, which raised
    # Encoding::UndefinedConversionError for any name outside ASCII.
    it "finds a tag whose name is not ASCII" do
      described_class.create!(name: "привет")

      expect(described_class.named_any(["привет"]).map(&:name)).to eq(["привет"])
    end

    it "does not raise for a mix of ASCII and non-ASCII names" do
      described_class.create!(name: "ruby")
      described_class.create!(name: "日本語")

      expect { described_class.named_any(%w[ruby 日本語]).to_a }.not_to raise_error
    end
  end

  describe ".named_like" do
    it "finds a tag containing the fragment" do
      described_class.create!(name: "ruby on rails")

      expect(described_class.named_like("on rai").map(&:name)).to eq(["ruby on rails"])
    end

    it "treats an underscore in the fragment as a literal" do
      described_class.create!(name: "ruby_lang")
      described_class.create!(name: "rubyxlang")

      expect(described_class.named_like("ruby_lang").map(&:name)).to eq(["ruby_lang"])
    end

    it "treats a percent sign in the fragment as a literal" do
      described_class.create!(name: "100% cotton")

      expect(described_class.named_like("100%").map(&:name)).to eq(["100% cotton"])
    end
  end

  describe ".named_like_any" do
    it "finds tags matching any of the fragments" do
      described_class.create!(name: "ruby")
      described_class.create!(name: "rails")
      described_class.create!(name: "python")

      expect(described_class.named_like_any(%w[rub rai]).map(&:name)).to match_array(%w[ruby rails])
    end
  end

  describe ".for_context" do
    it "returns tags used in that context" do
      TaggableModel.create!(name: "Bob", skill_list: "diving")

      expect(described_class.for_context(:skills).map(&:name)).to eq(["diving"])
    end

    it "excludes tags used only in another context" do
      TaggableModel.create!(name: "Bob", skill_list: "diving")

      expect(described_class.for_context(:languages)).to be_empty
    end
  end

  describe ".find_or_create_with_like_by_name" do
    it "creates a tag that does not exist" do
      expect {
        described_class.find_or_create_with_like_by_name("ruby")
      }.to change(described_class, :count).by(1)
    end

    it "returns the existing tag rather than creating another" do
      existing = described_class.create!(name: "ruby")

      expect(described_class.find_or_create_with_like_by_name("ruby")).to eq(existing)
    end

    it "does not return a different tag that merely contains the name" do
      described_class.create!(name: "ruby on rails")

      expect(described_class.find_or_create_with_like_by_name("ruby").name).to eq("ruby")
    end

    it "matches an existing tag differing in case" do
      described_class.create!(name: "Ruby")

      expect {
        described_class.find_or_create_with_like_by_name("ruby")
      }.not_to change(described_class, :count)
    end
  end

  describe ".find_or_create_all_with_like_by_name" do
    it "returns an empty array for an empty list" do
      expect(described_class.find_or_create_all_with_like_by_name([])).to eq([])
    end

    it "creates every tag in the list" do
      expect {
        described_class.find_or_create_all_with_like_by_name(%w[ruby rails])
      }.to change(described_class, :count).by(2)
    end

    it "returns the tags in the order the names were given" do
      names = described_class.find_or_create_all_with_like_by_name(%w[ruby rails]).map(&:name)

      expect(names).to eq(%w[ruby rails])
    end

    it "reuses a tag that already exists" do
      described_class.create!(name: "ruby")

      expect {
        described_class.find_or_create_all_with_like_by_name(%w[ruby rails])
      }.to change(described_class, :count).by(1)
    end

    it "accepts the names as separate arguments" do
      names = described_class.find_or_create_all_with_like_by_name("ruby", "rails").map(&:name)

      expect(names).to eq(%w[ruby rails])
    end

    it "creates a tag whose name is not ASCII" do
      names = described_class.find_or_create_all_with_like_by_name(%w[привет 日本語]).map(&:name)

      expect(names).to eq(%w[привет 日本語])
    end

    it "treats names differing only in case as one tag" do
      expect {
        described_class.find_or_create_all_with_like_by_name(%w[Ruby ruby])
      }.to change(described_class, :count).by(1)
    end

    it "returns the same tag for both spellings of a name" do
      tags = described_class.find_or_create_all_with_like_by_name(%w[Ruby ruby])

      expect(tags.first).to eq(tags.last)
    end

    it "treats names differing only in case as separate tags when strict_case_match is on" do
      MakeTaggable.strict_case_match = true

      expect {
        described_class.find_or_create_all_with_like_by_name(%w[Ruby ruby])
      }.to change(described_class, :count).by(2)
    end
  end

  describe "tagging a record" do
    # The tag list cleans itself before it reaches the tag lookup, so the two
    # spellings collapse a step earlier than the specs above exercise.
    it "creates one tag for two spellings of a name" do
      expect {
        TaggableModel.create!(name: "Bob", tag_list: "Rails, rails")
      }.to change(described_class, :count).by(1)
    end
  end

  describe "#==" do
    it "is equal to another tag with the same name" do
      expect(described_class.new(name: "ruby")).to eq(described_class.new(name: "ruby"))
    end

    it "is not equal to a tag with a different name" do
      expect(described_class.new(name: "ruby")).not_to eq(described_class.new(name: "rails"))
    end

    it "is not equal to a plain string of the same name" do
      expect(described_class.new(name: "ruby")).not_to eq("ruby")
    end
  end

  describe "#to_s" do
    it "is the tag name" do
      expect(described_class.new(name: "ruby").to_s).to eq("ruby")
    end
  end

  describe "#count" do
    it "is zero on a tag loaded without a count" do
      expect(described_class.create!(name: "ruby").count).to eq(0)
    end

    it "reads the count selected by a counting query" do
      TaggableModel.create!(name: "Bob", skill_list: "diving")

      expect(TaggableModel.tag_counts_on(:skills).first.count).to eq(1)
    end
  end

  describe "scopes" do
    it "orders most_used by taggings_count descending" do
      described_class.create!(name: "rare", taggings_count: 1)
      described_class.create!(name: "common", taggings_count: 9)

      expect(described_class.most_used.map(&:name)).to eq(%w[common rare])
    end

    it "orders least_used by taggings_count ascending" do
      described_class.create!(name: "rare", taggings_count: 1)
      described_class.create!(name: "common", taggings_count: 9)

      expect(described_class.least_used.map(&:name)).to eq(%w[rare common])
    end

    it "limits most_used to the given number" do
      3.times { |i| described_class.create!(name: "tag#{i}", taggings_count: i) }

      expect(described_class.most_used(2).count).to eq(2)
    end
  end

  describe "taggings" do
    it "destroys its taggings when the tag is destroyed" do
      TaggableModel.create!(name: "Bob", skill_list: "diving")
      tag = described_class.find_by(name: "diving")

      expect { tag.destroy }.to change(MakeTaggable::Tagging, :count).by(-1)
    end

    it "counts its taggings in taggings_count" do
      TaggableModel.create!(name: "Bob", skill_list: "diving")

      expect(described_class.find_by(name: "diving").taggings_count).to eq(1)
    end
  end
end
