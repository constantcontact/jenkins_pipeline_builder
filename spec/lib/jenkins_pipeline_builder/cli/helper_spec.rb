require File.expand_path('../../spec_helper', __FILE__)

describe JenkinsPipelineBuilder::CLI::Helper do

  let(:generator) do
    instance_double(
      JenkinsPipelineBuilder::Generator,
      :debug= => true
    )
  end

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
    expect(JenkinsPipelineBuilder).to receive(:generator).and_return(generator)
    options[:server] = '127.0.0.1'
    expected_options[:server_ip] = '127.0.0.1'
    described_class.setup(options)
  end

  it 'should handle server arg being an ipv6 address' do
    expect(JenkinsPipelineBuilder).to receive(:credentials=).with(expected_options)
    expect(JenkinsPipelineBuilder).to receive(:generator).and_return(generator)
    options[:server] = '::1'
    expected_options[:server_ip] = '::1'
    described_class.setup(options)
  end

  it 'should handle server arg being a url' do
    expect(JenkinsPipelineBuilder).to receive(:credentials=).with(expected_options)
    expect(JenkinsPipelineBuilder).to receive(:generator).and_return(generator)
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
