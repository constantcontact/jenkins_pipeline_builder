require File.expand_path('../spec_helper', __FILE__)

describe 'ModuleRegistry' do

  it 'needs more tests'
  it 'should return item by a specified path' do

    registry = JenkinsPipelineBuilder::ModuleRegistry.new
    ext = double
    allow(ext).to receive(:name).and_return :foo
    expect(ext).to receive(:jenkins_name).and_return 'jenkins name'
    expect(ext).to receive(:description).and_return 'description'
    registry.register_job_attribute(ext)

    expect(registry.get('job/foo').name).to eq :foo
  end
end
