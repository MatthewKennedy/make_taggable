# -*- encoding : utf-8 -*-
require 'spec_helper'

describe Uggle::Tagging do
  before(:each) do
    @tagging = Uggle::Tagging.new
  end

  it 'should not be valid with a invalid tag' do
    @tagging.taggable = TaggableModel.create(name: 'Bob Jones')
    @tagging.tag = Uggle::Tag.new(name: '')
    @tagging.context = 'tags'

    expect(@tagging).to_not be_valid

    expect(@tagging.errors[:tag_id]).to eq(['can\'t be blank'])
  end

  it 'should not create duplicate taggings' do
    @taggable = TaggableModel.create(name: 'Bob Jones')
    @tag = Uggle::Tag.create(name: 'awesome')

    expect(-> {
      2.times { Uggle::Tagging.create(taggable: @taggable, tag: @tag, context: 'tags') }
    }).to change(Uggle::Tagging, :count).by(1)
  end

  it 'should not delete tags of other records' do
    6.times { TaggableModel.create(name: 'Bob Jones', tag_list: 'very, serious, bug') }
    expect(Uggle::Tag.count).to eq(3)
    taggable = TaggableModel.first
    taggable.tag_list = 'bug'
    taggable.save

    expect(taggable.tag_list).to eq(['bug'])

    another_taggable = TaggableModel.where('id != ?', taggable.id).sample
    expect(another_taggable.tag_list.sort).to eq(%w(very serious bug).sort)
  end

  it 'should destroy unused tags after tagging destroyed' do
    previous_setting = Uggle.remove_unused_tags
    Uggle.remove_unused_tags = true
    Uggle::Tag.destroy_all
    @taggable = TaggableModel.create(name: 'Bob Jones')
    @taggable.update_attribute :tag_list, 'aaa,bbb,ccc'
    @taggable.update_attribute :tag_list, ''
    expect(Uggle::Tag.count).to eql(0)
    Uggle.remove_unused_tags = previous_setting
  end

  describe 'context scopes' do
    before do
      @tagging_2 = Uggle::Tagging.new
      @tagging_3 = Uggle::Tagging.new

      @tagger = User.new
      @tagger_2 = User.new

      @tagging.taggable = TaggableModel.create(name: "Black holes")
      @tagging.tag = Uggle::Tag.create(name: "Physics")
      @tagging.tagger = @tagger
      @tagging.context = 'Science'
      @tagging.save

      @tagging_2.taggable = TaggableModel.create(name: "Satellites")
      @tagging_2.tag = Uggle::Tag.create(name: "Technology")
      @tagging_2.tagger = @tagger_2
      @tagging_2.context = 'Science'
      @tagging_2.save

      @tagging_3.taggable = TaggableModel.create(name: "Satellites")
      @tagging_3.tag = Uggle::Tag.create(name: "Engineering")
      @tagging_3.tagger = @tagger_2
      @tagging_3.context = 'Astronomy'
      @tagging_3.save

    end

    describe '.owned_by' do
      it "should belong to a specific user" do
        expect(Uggle::Tagging.owned_by(@tagger).first).to eq(@tagging)
      end
    end

    describe '.by_context' do
      it "should be found by context" do
        expect(Uggle::Tagging.by_context('Science').length).to eq(2);
      end
    end

    describe '.by_contexts' do
      it "should find taggings by contexts" do
        expect(Uggle::Tagging.by_contexts(['Science', 'Astronomy']).first).to eq(@tagging);
        expect(Uggle::Tagging.by_contexts(['Science', 'Astronomy']).second).to eq(@tagging_2);
        expect(Uggle::Tagging.by_contexts(['Science', 'Astronomy']).third).to eq(@tagging_3);
        expect(Uggle::Tagging.by_contexts(['Science', 'Astronomy']).length).to eq(3);
      end
    end

    describe '.not_owned' do
      before do
        @tagging_4 = Uggle::Tagging.new
        @tagging_4.taggable = TaggableModel.create(name: "Gravity")
        @tagging_4.tag = Uggle::Tag.create(name: "Space")
        @tagging_4.context = "Science"
        @tagging_4.save
      end

      it "should found the taggings that do not have owner" do
        expect(Uggle::Tagging.all.length).to eq(4)
        expect(Uggle::Tagging.not_owned.length).to eq(1)
        expect(Uggle::Tagging.not_owned.first).to eq(@tagging_4)
      end
    end
  end
end
