require "spec_helper"

# The documentation is written and read on whatever Ruby and Rails the author
# happens to have. These examples hold it to the versions the gemspec actually
# promises, which is where two bugs had already slipped through: params.expect
# and ActiveRecord::Migration[8.0] both fail on Active Record 7.2.
module Documentation
  ROOT = Pathname.new(File.expand_path("..", __dir__))

  # The changelog is a record of what the code used to do, so it quotes calls
  # that were wrong on purpose -- including the two these checks exist to catch.
  # Only documentation that instructs the reader is held to the floor.
  HISTORICAL = ["CHANGELOG.md"].freeze

  FILES = (ROOT.glob("*.md") + ROOT.glob("docs/*.md"))
    .reject { |path| HISTORICAL.include?(path.basename.to_s) }
    .sort
    .freeze

  # The floor comes from the gemspec, so raising the minimum cannot silently
  # leave these checks testing the wrong version.
  SUPPORTED_FLOOR = Gem::Specification.load(ROOT.join("make_taggable.gemspec").to_s)
    .dependencies
    .find { |dependency| dependency.name == "activerecord" }
    .requirement
    .requirements
    .filter_map { |operator, version| version if operator == ">=" }
    .max

  # Calls that do not exist across the whole supported range. A document using
  # one has to show what to write instead.
  VERSION_SENSITIVE_CALLS = {
    "params.expect" => {since: Gem::Version.new("8.0"), alternative: "params.require"}
  }.freeze

  ##
  # Every ```ruby block in a file, as [line number, source] pairs.
  #
  # @param path [Pathname] the document to read
  # @return [Array<Array(Integer, String)>]
  #
  def self.ruby_blocks(path)
    blocks = []
    current = nil

    path.read.lines.each_with_index do |line, index|
      if current
        if line.start_with?("```")
          blocks << [current[:line], current[:source].join]
          current = nil
        else
          current[:source] << line
        end
      elsif line.start_with?("```ruby")
        current = {line: index + 2, source: []}
      end
    end

    blocks
  end
end

RSpec.describe "documentation" do
  it "reads a supported floor from the gemspec to check against" do
    expect(Documentation::SUPPORTED_FLOOR).to be_a(Gem::Version)
  end

  it "finds documents to check" do
    expect(Documentation::FILES).not_to be_empty
  end

  Documentation::FILES.each do |path|
    describe path.relative_path_from(Documentation::ROOT).to_s do
      Documentation.ruby_blocks(path).each do |line, source|
        it "parses the Ruby block at line #{line}" do
          expect { RubyVM::AbstractSyntaxTree.parse(source) }.not_to raise_error
        end
      end

      it "declares example migrations at a version the gem supports" do
        floor = Documentation::SUPPORTED_FLOOR
        declared = path.read.scan(/ActiveRecord::Migration\[(\d+\.\d+)\]/).flatten.map { |v| Gem::Version.new(v) }

        too_new = declared.select { |version| version > floor }

        expect(too_new).to be_empty,
          "ActiveRecord::Migration#{too_new.map(&:to_s)} is newer than the supported floor " \
          "#{floor}, and raises ArgumentError there. Use [#{floor}]."
      end

      it "shows an alternative for calls the supported floor does not have" do
        floor = Documentation::SUPPORTED_FLOOR
        contents = path.read

        missing = Documentation::VERSION_SENSITIVE_CALLS.filter_map do |call, requirement|
          next unless contents.include?(call)
          next if requirement[:since] <= floor
          next if contents.include?(requirement[:alternative])

          "#{call} needs Rails #{requirement[:since]}, but the gem supports #{floor}. " \
            "Show #{requirement[:alternative]} alongside it."
        end

        expect(missing).to be_empty, missing.join("\n")
      end

      it "links only to files that exist" do
        broken = path.read.scan(/\[[^\]]+\]\(([^)#]+?)(?:#[^)]*)?\)/).flatten.reject do |target|
          target.start_with?("http://", "https://", "mailto:") || (path.dirname + target).exist?
        end

        expect(broken).to be_empty
      end
    end
  end

  # The changelog is exempt from the checks above -- it quotes calls that were
  # wrong on purpose -- but its structure still matters, because a release reads
  # it. Cutting a release renames the Unreleased heading, and a second one left
  # above the previous version silently keeps its entries out of the release
  # that shipped them. That happened to 1.7.0.
  describe "CHANGELOG.md" do
    let(:headings) { Documentation::ROOT.join("CHANGELOG.md").read.scan(/^## \[[^\]]+\].*$/) }

    it "has at most one Unreleased heading" do
      unreleased = headings.grep(/^## \[Unreleased\]/)

      expect(unreleased.size).to be <= 1,
        "found #{unreleased.size} Unreleased headings. Entries under the lower one will be missed " \
        "by the next release, which renames the first."
    end

    it "puts the Unreleased heading first when it has one" do
      next if headings.grep(/^## \[Unreleased\]/).empty?

      expect(headings.first).to match(/^## \[Unreleased\]/)
    end

    it "names every other heading as a version and a date" do
      versioned = headings.reject { |heading| heading.start_with?("## [Unreleased]") }

      malformed = versioned.reject { |heading| heading.match?(/^## \[\d+\.\d+\.\d+\] - \d{4}-\d{2}-\d{2}$/) }

      expect(malformed).to be_empty, malformed.join("\n")
    end

    it "lists versions newest first" do
      versions = headings.filter_map { |heading| heading[/\[(\d+\.\d+\.\d+)\]/, 1] }.map { |v| Gem::Version.new(v) }

      expect(versions).to eq(versions.sort.reverse)
    end

    it "has an entry for the version the gem currently reports" do
      next if headings.first&.start_with?("## [Unreleased]")

      expect(headings.first).to include("[#{MakeTaggable::VERSION}]")
    end
  end
end
