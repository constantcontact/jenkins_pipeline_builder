require File.expand_path('../../spec_helper', __FILE__)

describe 'builders' do

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
    File.open("./out/xml/builder_#{name}.xml", 'w') { |f| @n_xml.write_xml_to f }
  end

  context 'multi_job builder' do
    it 'generates a configuration' do
      params = { builders: { multi_job: { phases: { foo: { jobs: [{ name: 'foo' }] } } } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      builder = @n_xml.root.children.first
      expect(builder.name).to match 'com.tikal.jenkins.plugins.multijob.MultiJobBuilder'
    end

    it 'provides job specific config' do
      params = { builders: { multi_job: { phases: { foo: { jobs: [{ name: 'foo', config: {
        predefined_build_parameters: 'bar'
      } }] } } } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      node = @n_xml.xpath '//hudson.plugins.parameterizedtrigger.PredefinedBuildParameters'
      expect(node.children.first.content).to eq 'bar'
    end
  end
end
