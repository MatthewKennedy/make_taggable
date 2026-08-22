require "spec_helper"

RSpec.describe MakeTaggable do
  it "has a version number" do
    expect(MakeTaggable::VERSION).not_to be nil
  end

  describe "autoloads" do
    it "does not advertise a constant it cannot load" do
      pending_autoloads = MakeTaggable.constants.select { |c| MakeTaggable.autoload?(c) }

      unloadable = pending_autoloads.reject do |constant|
        MakeTaggable.const_get(constant)
        true
      rescue LoadError, NameError
        false
      end

      expect(unloadable).to be_empty
    end
  end

  describe ".delimiter=" do
    around do |example|
      previous_logger = ActiveRecord::Base.logger
      previous_delimiter = MakeTaggable.delimiter
      example.run
    ensure
      ActiveRecord::Base.logger = previous_logger
      MakeTaggable.instance_variable_get(:@configuration)
        .instance_variable_set(:@delimiter, previous_delimiter)
    end

    it "does not raise when Active Record has no logger" do
      ActiveRecord::Base.logger = nil

      expect { MakeTaggable.delimiter = ";" }.not_to raise_error
    end

    it "still assigns the delimiter when Active Record has no logger" do
      ActiveRecord::Base.logger = nil
      MakeTaggable.delimiter = ";"

      expect(MakeTaggable.delimiter).to eq(";")
    end
  end
end
