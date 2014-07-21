require File.expand_path('../../spec_helper', __FILE__)

describe 'publishers' do

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
    builder = Nokogiri::XML::Builder.new { |xml| xml.publishers }
    @n_xml = builder.doc
  end

  after :each do |example|
    name = example.description.gsub ' ', '_'
    File.open("./out/xml/publisher_#{name}.xml", 'w') { |f| @n_xml.write_xml_to f }
  end

  context 'sonar publisher' do
    it 'generates a configuration' do
      params = { publishers: { sonar_result: {} } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      sonar_publisher = @n_xml.root.children.first
      expect(sonar_publisher.name).to match 'hudson.plugins.sonar.SonarPublisher'
    end

    it 'populates branch' do
      params = { publishers: { sonar_result: { branch: 'test' } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      sonar_nodes = @n_xml.root.children.first.children
      branch = sonar_nodes.select { |node| node.name == 'branch' }
      expect(branch.first.content).to match 'test'
    end

    it 'populates maven installation name' do
      params = { publishers: { sonar_result: { maven_installation_name: 'test' } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      sonar_nodes = @n_xml.root.children.first.children
      maven_installation_name = sonar_nodes.select { |node| node.name == 'mavenInstallationName' }
      expect(maven_installation_name.first.content).to match 'test'
    end
  end

  context 'description_setter' do
    it 'generates a configuration' do
      params = { publishers: { description_setter: {} } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      publisher = @n_xml.root.children.first
      expect(publisher.name).to match 'hudson.plugins.descriptionsetter.DescriptionSetterPublisher'
    end
  end

  context 'downstream' do
    it 'generates a configuration' do
      params = { publishers: { downstream: {} } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      publisher = @n_xml.root.children.first
      expect(publisher.name).to match 'hudson.plugins.parameterizedtrigger.BuildTrigger'
    end

    it 'populates data'
    it 'passes params'
    it 'sets the file'
  end

  context 'hipchat' do
    it 'generates a configuration'
    it 'does an option'
  end

  context 'git' do
    it 'generates a configuration'
    it 'does an option'
  end

  context 'junit_result' do
    it 'generates a configuration'
    it 'does an option'
  end

  context 'coverage_result' do
    it 'generates a configuration'
    it 'does an option'
  end

  context 'post_build_script' do
    it 'generates a configuration'
    it 'does an option'
  end

  context 'groovy_postbuild' do
    it 'generates a configuration'
    it 'does an option'
  end

  context 'archive_artifact' do
    it 'generates a configuration'
    it 'does an option'
  end

  context 'email_notification' do
    it 'generates a configuration'
    it 'does an option'
  end
end
