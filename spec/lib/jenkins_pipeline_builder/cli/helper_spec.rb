require File.expand_path('../../spec_helper', __FILE__)

describe JenkinsPipelineBuilder::CLI::Helper do
  context '#setup' do
    let(:creds_file_base) { 'spec/lib/jenkins_pipeline_builder/fixtures/sample_creds' }

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
        expect(YAML).to receive(:load_file).and_call_original
        expect(JenkinsPipelineBuilder).to receive(:credentials=).with(expected_options)
        described_class.setup(options)
      end

      it 'should handle credentials passed as a json file' do
        options = {
          creds_file: "#{creds_file_base}.json"
        }
        expect(JSON).to receive(:parse).and_call_original
        expect(JenkinsPipelineBuilder).to receive(:credentials=).with(expected_options)
        described_class.setup(options)
      end

      it 'should handle credentials passed as a ruby file' do
        options = {
          creds_file: "#{creds_file_base}.rb"
        }
        expect(File).to receive(:expand_path).with(options[:creds_file]).and_call_original
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
        expect(JenkinsPipelineBuilder).to receive(:debug!).and_return true
        described_class.setup(options)
      end

      it 'should puts and error to stdout and exit if no credentials are passed' do
        allow(File).to receive(:exist?).and_return(false)
        expect($stderr).to receive(:puts).with(/Credentials are not set/)
        expect { described_class.setup({}) }.to raise_error(SystemExit, 'exit')
      end
    end

    context 'default credential files' do
      let(:default_creds_base) { '/foo/.jenkins_api_client/login' }

      before(:each) do
        allow(ENV).to receive(:[]).with('HOME').and_return '/foo'
      end

      it 'checks for all 3 supported formats in order' do
        expect(File).to receive(:exist?).with("#{default_creds_base}.rb")
        expect(File).to receive(:exist?).with("#{default_creds_base}.json")
        expect(File).to receive(:exist?).with("#{default_creds_base}.yaml")
        expect { described_class.setup({}) }.to raise_error(SystemExit, 'exit')
      end

      it 'loads the default ruby file' do
        expect(File).to receive(:exist?).with("#{default_creds_base}.rb").and_return true
        expect(File).to receive(:expand_path).with("#{default_creds_base}.rb").and_return "#{creds_file_base}.rb"
        described_class.setup({})
      end

      it 'loads the default json file' do
        expect(File).to receive(:exist?).with("#{default_creds_base}.rb").and_return false
        expect(File).to receive(:exist?).with("#{default_creds_base}.json").and_return true
        expect(File).to receive(:expand_path).with("#{default_creds_base}.json").and_return "#{creds_file_base}.json"
        expect(JSON).to receive(:parse).and_call_original
        described_class.setup({})
      end

      it 'loads the default yaml file' do
        expect(File).to receive(:exist?).with("#{default_creds_base}.rb").and_return false
        expect(File).to receive(:exist?).with("#{default_creds_base}.json").and_return false
        expect(File).to receive(:exist?).with("#{default_creds_base}.yaml").and_return true
        expect(File).to receive(:expand_path).with("#{default_creds_base}.yaml").and_return "#{creds_file_base}.yaml"
        expect(YAML).to receive(:load_file).and_call_original
        described_class.setup({})
      end
    end
  end
end
