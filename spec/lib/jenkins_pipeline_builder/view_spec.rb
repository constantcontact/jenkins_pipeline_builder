require 'rspec'
require File.expand_path('../../../../lib/jenkins_pipeline_builder', __FILE__)

describe JenkinsPipelineBuilder::View do
  describe '#initialize' do
    it 'gets ready'
  end

  describe '#generate' do
    it 'calls create'
    it 'loads the YAML'
  end

  describe '#get_mode' do
    it 'is a list view'
    it 'is a my view'
    it 'is a nested view'
    it 'is a categorized view'
    it 'is a dashboard view'
    it 'is a multi job view'
    it 'is not recognized'
  end

  describe '#create_base_view' do
    it 'sends an api request'
    it 'uses the parent view if specified'
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

  describe '#get_columns' do
    it 'categorized view'
    it 'other views'
  end

  describe '#path_encode' do
    it 'escapes the path'
  end

  describe '#list_children' do
    it 'parent view specified'
    it 'no parent view'
  end

  describe '#delete' do
    it 'calls api'
    it 'parent view specified'
  end

  describe '#exists?' do
    context 'parent view specified' do
      it 'does exist'
      it 'doesn\'t exist'
    end
    context 'no parent view' do
      it 'does exist'
      it 'doesn\'t exist'
    end
  end
end
