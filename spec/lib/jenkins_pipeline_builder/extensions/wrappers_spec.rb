require File.expand_path('../../spec_helper', __FILE__)

describe 'wrappers' do
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
    builder = Nokogiri::XML::Builder.new { |xml| xml.buildWrappers }
    @n_xml = builder.doc
  end

  after :each do |example|
    name = example.description.gsub ' ', '_'
    File.open("./out/xml/wrapper_#{name}.xml", 'w') { |f| @n_xml.write_xml_to f }
  end

  context 'ansicolor' do
    before :each do
      JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:ansicolor].installed_version = '0.0'
    end

    it 'generates correct xml' do
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', { wrappers: { ansicolor: true } }, @n_xml)

      node = @n_xml.root.xpath('//buildWrappers/hudson.plugins.ansicolor.AnsiColorBuildWrapper')
      expect(node.first).to be_truthy
      expect(node.first.content).to eq 'xterm'
    end

    it 'fails parameters are passed' do
      params = { wrappers: { ansicolor: { config: false } } }
      expect do
        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      end.to raise_error
    end
  end

  context 'xvfb' do
    before :each do
      JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:xvfb].installed_version = '0.0'
    end

    it 'generates correct xml' do
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', { wrappers: { xvfb: {} } }, @n_xml)

      node = @n_xml.root.xpath('//buildWrappers/org.jenkinsci.plugins.xvfb.XvfbBuildWrapper')
      puts node.inspect
      t = node.css('timeout')
      puts t.inspect
      expect(node.first).to_not be_nil
    end
  end

  context 'timestamp' do
    before :each do
      JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:timestamp].installed_version = '0.0'
    end

    it 'generates correct xml' do
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', { wrappers: { timestamp: true } }, @n_xml)

      node = @n_xml.root.xpath('//buildWrappers/hudson.plugins.timestamper.TimestamperBuildWrapper')
      expect(node.first).to_not be_nil
    end
  end

  context 'nodejs' do
    before :each do
      JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:nodejs].installed_version = '0.0'
    end

    it 'generates correct xml' do
      params = { wrappers: { nodejs: { node_installation_name: 'Node-0.10.24' } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      node_path = '//buildWrappers/jenkins.plugins.nodejs.tools.NpmPackagesBuildWrapper/nodeJSInstallationName'
      node = @n_xml.root.xpath(node_path)
      expect(node.first.content).to match 'Node-0.10.24'
    end
  end

end
