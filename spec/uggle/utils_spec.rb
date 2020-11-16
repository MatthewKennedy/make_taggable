# -*- encoding : utf-8 -*-
require 'spec_helper'

describe Uggle::Utils do
  describe '#like_operator' do
    it 'should return \'ILIKE\' when the adapter is PostgreSQL' do
      allow(Uggle::Utils.connection).to receive(:adapter_name) { 'PostgreSQL' }
      expect(Uggle::Utils.like_operator).to eq('ILIKE')
    end

    it 'should return \'LIKE\' when the adapter is not PostgreSQL' do
      allow(Uggle::Utils.connection).to receive(:adapter_name) { 'MySQL' }
      expect(Uggle::Utils.like_operator).to eq('LIKE')
    end
  end

  describe '#sha_prefix' do
    it 'should return a consistent prefix for a given word' do
      expect(Uggle::Utils.sha_prefix('kittens')).to eq(Uggle::Utils.sha_prefix('kittens'))
      expect(Uggle::Utils.sha_prefix('puppies')).not_to eq(Uggle::Utils.sha_prefix('kittens'))
    end
  end
end
