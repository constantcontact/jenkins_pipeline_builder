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

  before(:each) do
    expect(JenkinsPipelineBuilder).to receive(:credentials=).with(expected_options)
    expect(JenkinsPipelineBuilder).to receive(:generator).and_return(generator)
  end

  it 'should handle server arg being an ip' do
    options[:server] = '127.0.0.1'
    expected_options[:server_ip] = '127.0.0.1'
    described_class.setup(options)
  end

  it 'should handle server arg being a url' do
    options[:server] = 'https://localhost.localdomain'
    expected_options[:server_url] = 'https://localhost.localdomain'
    described_class.setup(options)
  end
end
