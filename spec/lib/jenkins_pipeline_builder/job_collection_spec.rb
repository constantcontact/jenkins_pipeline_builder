require File.expand_path('spec_helper', __dir__)

describe JenkinsPipelineBuilder::JobCollection do
  before :all do
    JenkinsPipelineBuilder.credentials = {
      server_ip: '127.0.0.1',
      server_port: 8080,
      username: 'username',
      password: 'password',
      log_location: '/dev/null'
    }
  end

  after :each do
    JenkinsPipelineBuilder.registry.clear_versions
  end

  before :each do
    JenkinsPipelineBuilder.debug!
  end

  context '#load_from_path' do
    before :all do
      path = File.expand_path('fixtures/job_collection', __dir__)
      described_class.new.load_from_path path
    end

    after :all do
      JenkinsPipelineBuilder.registry.registry[:job][:publishers].delete(:my_test_thing)
    end

    it 'loads extensions' do
      expect(JenkinsPipelineBuilder.registry.registry[:job][:publishers]).to have_key :my_test_thing
    end

    it 'loads extension helpers' do
      extension = JenkinsPipelineBuilder.registry.registry[:job][:publishers][:my_test_thing].extension
      builder = Nokogiri::XML::Builder.new { |xml| xml.publishers }
      xml = builder.doc
      expect(extension.execute({}, xml)).to be true
      node = xml.css('thing').first
      expect(node.name).to eq 'thing'
      expect(node.content).to eq 'cool_stuff_method'
    end
  end
end
