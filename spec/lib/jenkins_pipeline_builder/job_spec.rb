require File.expand_path('../spec_helper', __FILE__)

describe JenkinsPipelineBuilder::Job do
  before :all do
    JenkinsPipelineBuilder.credentials = {
      server_ip: '127.0.0.1',
      server_port: 8080,
      username: 'username',
      password: 'password',
      log_location: '/dev/null'
    }
  end

  before :each do
    allow(JenkinsPipelineBuilder).to receive(:logger).and_return double(
      debug: true,
      info: true,
      warn: true,
      error: true,
      fatal: true
    )
  end

  context '#create_or_update' do
    before :each do
      @job_double = double
      @client = double job: @job_double
      allow(JenkinsPipelineBuilder).to receive(:client).and_return @client
    end

    let(:job) { described_class.new name: 'asdf' }

    it 'fails if to_xml fails' do
      expect(job).to receive(:to_xml).ordered.and_return [false, 'oops']
      expect(job.create_or_update).to eq [false, 'oops']
    end

    it 'does not call the client in debug mode' do
      expect(job).to receive(:to_xml).and_return [true, '']
      expect(JenkinsPipelineBuilder).to receive(:debug).and_return true
      expect(JenkinsPipelineBuilder).to_not receive(:file_mode)
      expect(JenkinsPipelineBuilder.client.job).to_not receive(:exists?)
      job.create_or_update
    end

    it 'does not call the client in file mode' do
      expect(job).to receive(:to_xml).and_return [true, '']
      expect(JenkinsPipelineBuilder).to receive(:debug).and_return false
      expect(JenkinsPipelineBuilder).to receive(:file_mode).and_return true
      expect(JenkinsPipelineBuilder.client.job).to_not receive(:exists?)
      job.create_or_update
    end

    it 'creates if the job does not exist' do
      expect(JenkinsPipelineBuilder).to receive(:debug).and_return false
      expect(JenkinsPipelineBuilder).to receive(:file_mode).and_return false
      expect(job).to receive(:to_xml).and_return [true, '']
      expect(@job_double).to receive(:exists?).with('asdf').and_return false
      expect(@job_double).to receive(:create).and_return true
      job.create_or_update
    end

    it 'updates if the job exists' do
      expect(JenkinsPipelineBuilder).to receive(:debug).and_return false
      expect(JenkinsPipelineBuilder).to receive(:file_mode).and_return false
      expect(job).to receive(:to_xml).and_return [true, '']
      expect(@job_double).to receive(:exists?).with('asdf').and_return true
      expect(@job_double).to receive(:update).and_return true
      job.create_or_update
    end
  end

  context '#to_xml' do
    it 'fails if the job has no name' do
      job = described_class.new foo: :bar
      expect { job.to_xml }.to raise_error 'Job name is not specified'
    end

    it 'parses inline job dsl' do
      job = described_class.new job_type: 'job_dsl', name: 'asdf', job_dsl: 'this is my job dsl'

      success, xml = job.to_xml
      expect(success).to be true
      expect(xml).to include 'javaposse.jobdsl.plugin.ExecuteDslScripts'
      expect(xml).to include 'usingScriptText>true'
      expect(xml).to include 'this is my job dsl'
    end

    it 'parses job dsl from a file' do
      job = described_class.new job_type: 'job_dsl', name: 'asdf', job_dsl_targets: 'targets'

      success, xml = job.to_xml
      expect(success).to be true
      expect(xml).to include 'javaposse.jobdsl.plugin.ExecuteDslScripts'
      expect(xml).to include 'targets>targets'
      expect(xml).to include 'usingScriptText>false'
    end

    it 'parses multi_job' do
      job = described_class.new job_type: 'multi_project', name: 'asdf'

      success, xml = job.to_xml
      expect(success).to be true
      expect(xml).to include 'com.tikal.jenkins.plugins.multijob.MultiJobProject'
    end

    it 'parses build flow' do
      job = described_class.new job_type: 'build_flow', name: 'asdf'

      success, xml = job.to_xml
      expect(success).to be true
      expect(xml).to include 'com.cloudbees.plugins.flow.BuildFlow'
    end

    it 'parses freestyle' do
      job = described_class.new job_type: 'free_style', name: 'asdf'

      success, xml = job.to_xml
      expect(success).to be true
      expect(xml).to_not include 'com.cloudbees.plugins.flow.BuildFlow'
      expect(xml).to_not include 'javaposse.jobdsl.plugin.ExecuteDslScripts'
      expect(xml).to_not include 'com.tikal.jenkins.plugins.multijob.MultiJobProject'
    end

    it 'parses pull request generator' do
      job = described_class.new job_type: 'pull_request_generator', name: 'asdf'

      success, xml = job.to_xml
      expect(success).to be true
      expect(xml).to_not include 'com.cloudbees.plugins.flow.BuildFlow'
      expect(xml).to_not include 'javaposse.jobdsl.plugin.ExecuteDslScripts'
      expect(xml).to_not include 'com.tikal.jenkins.plugins.multijob.MultiJobProject'
    end

    it 'fails on an unknown type' do
      job = described_class.new job_type: 'unknonw', name: 'asdf'

      success, _ = job.to_xml
      expect(success).to be false
    end
  end
end
