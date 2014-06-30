require File.expand_path('../spec_helper', __FILE__)

describe 'ModuleRegistry' do

  it 'needs more tests'
  it 'should return item by a specified path' do

    registry = JenkinsPipelineBuilder::ModuleRegistry.new
    ext = double
    allow(ext).to receive(:name).and_return :foo
    registry.register [:job], ext

    expect(registry.get('job/foo').name).to eq :foo
  end
end
