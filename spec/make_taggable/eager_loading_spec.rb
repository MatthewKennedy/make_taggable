require "spec_helper"

RSpec.describe "Reading tag lists across a collection" do
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

  before { 5.times { |i| TaggableModel.create!(name: "r#{i}", tag_list: "ruby, rails") } }

  it "reads the lists from the preload rather than querying per record" do
    queries = count_queries do
      TaggableModel.includes(:tags).limit(5).each { |record| record.tag_list.to_a }
    end

    # The records, then the two a has_many :through preload costs -- the
    # taggings and the tags. Three is the floor for includes(:tags); what
    # matters is that reading the lists adds nothing to it.
    expect(queries).to eq(3)
  end

  it "costs the same whatever the size of the collection" do
    5.times { |i| TaggableModel.create!(name: "extra#{i}", tag_list: "ruby") }

    five = count_queries { TaggableModel.includes(:tags).limit(5).each { |r| r.tag_list.to_a } }
    ten = count_queries { TaggableModel.includes(:tags).limit(10).each { |r| r.tag_list.to_a } }

    expect(ten).to eq(five)
  end

  it "returns the same lists either way" do
    eager = TaggableModel.includes(:tags).order(:id).map { |r| r.tag_list.to_a.sort }
    lazy = TaggableModel.order(:id).map { |r| r.tag_list.to_a.sort }

    expect(eager).to eq(lazy)
    expect(eager).to all(eq(%w[rails ruby]))
  end

  it "still works for a record loaded on its own" do
    record = TaggableModel.first

    expect(record.tag_list.to_a.sort).to eq(%w[rails ruby])
  end

  it "leaves owned tags out of the list when preloaded, as it does when not" do
    owner = User.create!(name: "owner")
    record = TaggableModel.create!(name: "owned", tag_list: "unowned")
    owner.tag(record, on: :tags, with: "mine")

    preloaded = TaggableModel.includes(:tags).find(record.id)

    expect(preloaded.tag_list.to_a).to eq(["unowned"])
    expect(preloaded.all_tags_list.to_a.sort).to eq(%w[mine unowned])
  end

  it "reflects a list assigned after the preload" do
    record = TaggableModel.includes(:tags).first
    record.tag_list = "changed"

    expect(record.tag_list.to_a).to eq(["changed"])
  end
end
