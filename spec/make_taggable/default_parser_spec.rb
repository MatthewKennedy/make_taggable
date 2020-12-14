require "spec_helper"

describe MakeTaggable::DefaultParser do
  it "#parse should return empty array if empty array is passed" do
    parser = MakeTaggable::DefaultParser.new([])
    expect(parser.parse).to be_empty
  end

  describe "Multiple Delimiter" do
    before do
      @old_delimiter = MakeTaggable.delimiter
    end

    after do
      MakeTaggable.delimiter = @old_delimiter
    end

    it "should separate tags by delimiters" do
      MakeTaggable.delimiter = [",", " ", '\|']
      parser = MakeTaggable::DefaultParser.new("cool, data|I have")
      expect(parser.parse.to_s).to eq("cool, data, I, have")
    end

    it "should escape quote" do
      MakeTaggable.delimiter = [",", " ", '\|']
      parser = MakeTaggable::DefaultParser.new("'I have'|cool, data")
      expect(parser.parse.to_s).to eq('"I have", cool, data')

      parser = MakeTaggable::DefaultParser.new('"I, have"|cool, data')
      expect(parser.parse.to_s).to eq('"I, have", cool, data')
    end

    it "should work for utf8 delimiter and long delimiter" do
      MakeTaggable.delimiter = ["，", "的", "可能是"]
      parser = MakeTaggable::DefaultParser.new("我的东西可能是不见了，还好有备份")
      expect(parser.parse.to_s).to eq("我， 东西， 不见了， 还好有备份")
    end

    it "should work for multiple quoted tags" do
      MakeTaggable.delimiter = [","]
      parser = MakeTaggable::DefaultParser.new('"Ruby Monsters","eat Katzenzungen"')
      expect(parser.parse.to_s).to eq("Ruby Monsters, eat Katzenzungen")
    end
  end
end
