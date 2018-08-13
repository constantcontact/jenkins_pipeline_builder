require File.expand_path('../lib/jenkins_pipeline_builder/spec_helper', __dir__)

describe 'Pipeline' do
  before :all do
    JenkinsPipelineBuilder.credentials = {
      server_ip: '127.0.0.1',
      server_port: 8080,
      username: 'username',
      password: 'password',
      log_location: '/dev/null'
    }
  end

  let(:generator) { JenkinsPipelineBuilder::Generator.new }

  it 'generates its own pipeline' do
    JenkinsPipelineBuilder.debug!
    generator.bootstrap './pipeline'
  end
end
