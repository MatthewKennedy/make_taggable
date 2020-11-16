# -*- encoding : utf-8 -*-
require 'spec_helper'

describe Uggle::DefaultParser do
  it '#parse should return empty array if empty array is passed' do
    parser = Uggle::DefaultParser.new([])
    expect(parser.parse).to be_empty
  end

  describe 'Multiple Delimiter' do
    before do
      @old_delimiter = Uggle.delimiter
    end

    after do
      Uggle.delimiter = @old_delimiter
    end

    it 'should separate tags by delimiters' do
      Uggle.delimiter = [',', ' ', '\|']
      parser = Uggle::DefaultParser.new('cool, data|I have')
      expect(parser.parse.to_s).to eq('cool, data, I, have')
    end

    it 'should escape quote' do
      Uggle.delimiter = [',', ' ', '\|']
      parser = Uggle::DefaultParser.new("'I have'|cool, data")
      expect(parser.parse.to_s).to eq('"I have", cool, data')

      parser = Uggle::DefaultParser.new('"I, have"|cool, data')
      expect(parser.parse.to_s).to eq('"I, have", cool, data')
    end

    it 'should work for utf8 delimiter and long delimiter' do
      Uggle.delimiter = ['，', '的', '可能是']
      parser = Uggle::DefaultParser.new('我的东西可能是不见了，还好有备份')
      expect(parser.parse.to_s).to eq('我， 东西， 不见了， 还好有备份')
    end

    it 'should work for multiple quoted tags' do
      Uggle.delimiter = [',']
      parser = Uggle::DefaultParser.new('"Ruby Monsters","eat Katzenzungen"')
      expect(parser.parse.to_s).to eq('Ruby Monsters, eat Katzenzungen')
    end
  end

end
