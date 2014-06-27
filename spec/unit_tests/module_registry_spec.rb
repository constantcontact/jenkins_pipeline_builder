require File.expand_path('../spec_helper', __FILE__)

describe 'ModuleRegistry' do

  it 'needs more tests'
  it 'should return item by a specified path' do

    registry = JenkinsPipelineBuilder::ModuleRegistry.new
    registry.register_job_attribute(:foo, 'jenkins name', 'desc', 'plugin_id', 1.0) do
      true
    end
    expect(registry.registry[:job][:foo][1.0]).to be_truthy
    #TODO test registered_modules
  end
end
