require File.expand_path('../../spec_helper', __FILE__)

describe JenkinsPipelineBuilder::CLI::Helper do


  context '#setup' do
    let(:generator) do
      instance_double(
        JenkinsPipelineBuilder::Generator,
        :debug= => true
      )
    end

    before(:each) do
      allow(JenkinsPipelineBuilder).to receive(:generator).and_return(generator)
    end

    context 'username and password given' do
      let(:options) do
        {
          username: 'username',
          password: 'password'
        }
      end

      let(:expected_options) do
        {
          username: 'username',
          password: 'password'
        }
      end

      it 'should handle server arg being an ipv4 address' do
        expect(JenkinsPipelineBuilder).to receive(:credentials=).with(expected_options)
        options[:server] = '127.0.0.1'
        expected_options[:server_ip] = '127.0.0.1'
        described_class.setup(options)
      end

      it 'should handle server arg being an ipv6 address' do
        expect(JenkinsPipelineBuilder).to receive(:credentials=).with(expected_options)
        options[:server] = '::1'
        expected_options[:server_ip] = '::1'
        described_class.setup(options)
      end

      it 'should handle server arg being a url' do
        expect(JenkinsPipelineBuilder).to receive(:credentials=).with(expected_options)
        options[:server] = 'https://localhost.localdomain'
        expected_options[:server_url] = 'https://localhost.localdomain'
        described_class.setup(options)
      end

      it 'should puts an error to stdout and exit if server is invalid' do
        options[:server] = 'not_valid_at_all'
        expect($stderr).to receive(:puts).with(/server given \(not_valid_at_all\)/)
        expect { described_class.setup(options) }.to raise_error(SystemExit, 'exit')
      end
    end

    context 'credential file given' do
      let(:creds_file_base) { 'spec/lib/jenkins_pipeline_builder/fixtures/sample_creds' }

      let(:expected_options) do
        {
          'username' => 'username',
          'password' => 'password',
          'server_url' => 'https://localhost.localdomain',
          'server_port' => 8080
        }
      end

      it 'should handle credentials passed as a yaml file' do
        options = {
          creds_file: "#{creds_file_base}.yaml"
        }
        expect(JenkinsPipelineBuilder).to receive(:credentials=).with(expected_options)
        described_class.setup(options)
      end

      it 'should handle credentials passed as a json file' do
        options = {
          creds_file: "#{creds_file_base}.json"
        }
        expect(JenkinsPipelineBuilder).to receive(:credentials=).with(expected_options)
        described_class.setup(options)
      end

      it 'should handle the debug flag' do
        options = { debug: true }
        expected_options = {
          username: :foo,
          password: :bar,
          server_ip: :baz
        }
        expect(JenkinsPipelineBuilder).to receive(:credentials=).with(expected_options)
        described_class.setup(options)
      end

      it 'should puts and error to stdout and exit if no credentials are passed' do
        expect($stderr).to receive(:puts).with(/Credentials are not set/)
        expect { described_class.setup({}) }.to raise_error(SystemExit, 'exit')
      end
    end
  end
end
