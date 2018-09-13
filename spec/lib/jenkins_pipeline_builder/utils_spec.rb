require File.expand_path('spec_helper', __dir__)

describe JenkinsPipelineBuilder::Utils do
  let(:utils) { JenkinsPipelineBuilder::Utils }
  describe '#symbolize_keys_deep!' do
    let(:string_hash) { { 'layer1' => { 'layer2' => { 'layer3' => 'value' } } } }
    let(:string_hash_symbols) { { layer1: { layer2: { layer3: 'value' } } } }
    it 'should symbolize the hash' do
      utils.symbolize_keys_deep!(string_hash)
      expect(string_hash).to eq(string_hash_symbols)
    end
  end
  describe '#hash_merge!' do
    let(:hash_with_array) { { name: 'withArray', value: { publishers: [{ downstream: true }, { other: true }] } } }
    let(:hash_with_array2) { { name: 'withArray', value: { publishers: [{ downstream: false }] } } }
    it 'deep merge two hashes' do
      utils.hash_merge!(hash_with_array, hash_with_array2)
      expect(hash_with_array[:value][:publishers].count).to eq(1)
      expect(hash_with_array[:value][:publishers][0][:downstream]).to be_falsey
    end
  end
end
