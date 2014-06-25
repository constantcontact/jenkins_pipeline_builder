require File.expand_path('../spec_helper', __FILE__)

describe 'ModuleRegistry' do

  it 'needs more tests'
  it 'should return item by a specified path' do

    registry = JenkinsPipelineBuilder::ModuleRegistry.new
    registry.register_job_attribute(:foo, 'jenkins name', 'desc') do
      true
    end

    puts registry.registry.inspect
    registry.get('job/foo').call.should be_true
  end
end
