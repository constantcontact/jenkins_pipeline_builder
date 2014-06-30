require File.expand_path('../spec_helper', __FILE__)

describe JenkinsPipelineBuilder::View do
  describe '#initialize' do
    it 'gets ready'
  end

  describe '#generate' do
    it 'calls create'
    it 'loads the YAML'
  end

  describe '#create' do
    context 'parent view is specified' do
      it 'needs to create the parent view'
      it 'creates the view'
      it 'deletes a view if overwriting'
      it 'uses the write URL for the path'
    end
    context 'no parent view' do
      it 'creates the view'
      it 'deletes a view if overwriting'
    end
    it 'calls the api'
  end
end
