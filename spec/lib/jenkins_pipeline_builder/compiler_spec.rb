require 'rspec'
require File.expand_path('../../../../lib/jenkins_pipeline_builder', __FILE__)

describe JenkinsPipelineBuilder::Compiler do
  describe '#resolve_value' do
    context 'job name resolution' do
      it 'resolves the name of the job'
    end
    context 'variable resolution' do
      it 'a project name'
      it 'a global variable'
      it 'a mixture of vars'
    end
  end

  describe '#get_settings_bag' do
    it 'merge settings'
  end

  describe '#compile' do
    context 'compile string' do
      it 'success'
      it 'failure'
    end

    context 'compile hash' do
      it 'success'
      it 'failure'
    end

    context 'compile array' do
      it 'success'
      it 'failure'
    end
  end
end
