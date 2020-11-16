# -*- encoding : utf-8 -*-
require 'spec_helper'

describe MakeTaggable::TagsHelper do
  before(:each) do
    @bob = TaggableModel.create(name: 'Bob Jones', language_list: 'ruby, php')
    @tom = TaggableModel.create(name: 'Tom Marley', language_list: 'ruby, java')
    @eve = TaggableModel.create(name: 'Eve Nodd', language_list: 'ruby, c++')

    @helper =
        class Helper
          include MakeTaggable::TagsHelper
        end.new
  end


  it 'should yield the proper css classes' do
    tags = {}

    @helper.tag_cloud(TaggableModel.tag_counts_on(:languages), %w(sucky awesome)) do |tag, css_class|
      tags[tag.name] = css_class
    end

    expect(tags['ruby']).to eq('awesome')
    expect(tags['java']).to eq('sucky')
    expect(tags['c++']).to eq('sucky')
    expect(tags['php']).to eq('sucky')
  end

  it 'should handle tags with zero counts (build for empty)' do
    MakeTaggable::Tag.create(name: 'php')
    MakeTaggable::Tag.create(name: 'java')
    MakeTaggable::Tag.create(name: 'c++')

    tags = {}

    @helper.tag_cloud(MakeTaggable::Tag.all, %w(sucky awesome)) do |tag, css_class|
      tags[tag.name] = css_class
    end

    expect(tags['java']).to eq('sucky')
    expect(tags['c++']).to eq('sucky')
    expect(tags['php']).to eq('sucky')
  end
end
