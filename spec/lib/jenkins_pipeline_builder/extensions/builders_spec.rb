require File.expand_path('../../spec_helper', __FILE__)

describe 'builders' do
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

  before :each do
    builder = Nokogiri::XML::Builder.new { |xml| xml.builders }
    @n_xml = builder.doc
  end

  after :each do |example|
    name = example.description.gsub ' ', '_'
    require 'fileutils'
    FileUtils.mkdir_p 'out/xml'
    File.open("./out/xml/builder_#{name}.xml", 'w') { |f| @n_xml.write_xml_to f }
  end

  context 'generic' do
    it 'can register a builder' do
      result = builder do
        name :test_generic
        plugin_id :foo
        xml do
          foo :bar
        end
      end
      JenkinsPipelineBuilder.registry.registry[:job][:builders].delete :test_generic
      expect(result).to be true
    end

    it 'fails to register an invalid builder' do
      result = builder do
        name :test_generic
      end
      JenkinsPipelineBuilder.registry.registry[:job][:builders].delete :test_generic
      expect(result).to be false
    end
  end

  context 'multi_job builder' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'jenkins-multijob-plugin' => '20.0' })
    end
    it 'generates a configuration' do
      params = { builders: { multi_job: { phases: { foo: { jobs: [{ name: 'foo' }] } } } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      builder = @n_xml.root.children.first
      expect(builder.name).to match 'com.tikal.jenkins.plugins.multijob.MultiJobBuilder'
    end

    it 'provides job specific config' do
      params = { builders: { multi_job: { phases: { foo: { jobs: [{ name: 'foo', config: {
        predefined_build_parameters: 'bar',
        properties_file: { file: 'props', skip_if_missing: true }
      } }] } } } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      node = @n_xml.xpath '//hudson.plugins.parameterizedtrigger.PredefinedBuildParameters'
      expect(node.children.first.content).to eq 'bar'

      node = @n_xml.xpath '//hudson.plugins.parameterizedtrigger.FileBuildParameters/propertiesFile'
      expect(node.children.first.content).to eq 'props'

      node = @n_xml.xpath '//hudson.plugins.parameterizedtrigger.FileBuildParameters/failTriggerOnMissing'
      expect(node.children.first.content).to eq 'true'
    end
  end
end
