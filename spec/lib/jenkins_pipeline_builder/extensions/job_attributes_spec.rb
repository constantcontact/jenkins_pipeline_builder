require File.expand_path('../../spec_helper', __FILE__)

describe 'job_attributes' do
  after :each do
    JenkinsPipelineBuilder.registry.clear_versions
  end

  before :all do
    JenkinsPipelineBuilder.credentials = {
      server_ip: '127.0.0.1',
      server_port: 8080,
      username: 'username',
      password: 'password',
      log_location: '/dev/null'
    }
  end

  after :each do |example|
    name = example.description.gsub ' ', '_'
    File.open("./out/xml/job_attribute_#{name}.xml", 'w') { |f| @n_xml.write_xml_to f }
  end

  context 'scm params' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'git' => '20.0' })

      builder = Nokogiri::XML::Builder.new { |xml| xml.scm }
      @n_xml = builder.doc

      Nokogiri::XML::Builder.with(@n_xml.xpath('//scm').first) do |xml|
        xml.userRemoteConfigs do
          xml.send('hudson.plugins.git.UserRemoteConfig') do
            xml.url 'http://foo.com'
          end
        end
      end
    end

    it 'writes one block when both refspec and remote_name' do
      params = { scm_params: { refspec: :bar, remote_name: :foo }, scm_url: 'http://foo.com' }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      remote_config = @n_xml.root.children.first.children.first

      expect(remote_config.name).to match 'hudson.plugins.git.UserRemoteConfig'

      expect(remote_config.css('name').first).to be_truthy
      expect(remote_config.css('refspec').first).to be_truthy

      expect(remote_config.css('name').first.content).to eq 'foo'
      expect(remote_config.css('refspec').first.content).to eq 'bar'
    end

    it 'using remote_name does not remove the remote url' do
      params = { scm_params: { remote_name: :foo }, scm_url: 'http://foo.com' }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      remote_config = @n_xml.root.children.first.children.first

      expect(remote_config.name).to match 'hudson.plugins.git.UserRemoteConfig'

      expect(remote_config.css('name').first).to be_truthy
      expect(remote_config.css('url').first).to be_truthy

      expect(remote_config.css('name').first.content).to eq 'foo'
      expect(remote_config.css('url').first.content).to eq 'http://foo.com'
    end
  end
end
