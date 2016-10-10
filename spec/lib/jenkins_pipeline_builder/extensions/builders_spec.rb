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
    name = example.description.tr ' ', '_'
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
        list_installed: { 'jenkins-multijob-plugin' => '20.0' }
      )
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

  context 'maven3' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'maven-plugin' => '20.0' }
      )
    end

    it 'generates a configuration' do
      params = { builders: { maven3: {} } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      builder = @n_xml.root.children.first
      expect(builder.name).to match 'org.jfrog.hudson.maven3.Maven3Builder'
      expect(@n_xml.root.css('mavenName').first.text).to eq 'tools-maven-3.0.3'
    end
  end

  context 'blocking_downstream' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'parameterized-trigger' => '20.0' }
      )

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      builder = @n_xml.root.children.first
      expect(builder.name).to match 'hudson.plugins.parameterizedtrigger.TriggerBuilder'
    end

    context 'step failure threshold' do
      let(:params) { { builders: { blocking_downstream: { fail: 'FAILURE' } } } }

      it 'generates a configuration' do
        expect(@n_xml.root.css('buildStepFailureThreshold').first).to_not be_nil
        expect(@n_xml.root.css('buildStepFailureThreshold').first.css('color').first.text).to eq 'RED'
      end
    end

    context 'unstable threshold' do
      let(:params) { { builders: { blocking_downstream: { mark_unstable: 'UNSTABLE' } } } }

      it 'generates a configuration' do
        expect(@n_xml.root.css('unstableThreshold').first).to_not be_nil
        expect(@n_xml.root.css('unstableThreshold').first.css('color').first.text).to eq 'YELLOW'
      end
    end

    context 'failure threshold' do
      let(:params) { { builders: { blocking_downstream: { mark_fail: 'FAILURE' } } } }

      it 'generates a configuration' do
        expect(@n_xml.root.css('failureThreshold').first).to_not be_nil
        expect(@n_xml.root.css('failureThreshold').first.css('color').first.text).to eq 'RED'
      end
    end
  end

  context 'system_groovy' do
    error = ''
    before :each do
      error = ''
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'groovy' => '1.24' }
      )

      begin
        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      rescue RuntimeError => boom
        puts "Caught error #{boom}"
        error = boom.to_s
      end
      builder = @n_xml.root.children.first
      expect(builder.name).to match 'hudson.plugins.groovy.SystemGroovy'
    end

    context 'script given as string' do
      let(:params) { { builders: { system_groovy: { script: 'print "Hello world"' } } } }

      it 'generates a configuration' do
        node = @n_xml.xpath '//hudson.plugins.groovy.SystemGroovy/scriptSource/command'
        expect(node.children.first.content).to eq 'print "Hello world"'
      end
    end

    context 'script given as file' do
      let(:params) { { builders: { system_groovy: { file: 'myScript.groovy' } } } }

      it 'generates a configuration' do
        node = @n_xml.xpath '//hudson.plugins.groovy.SystemGroovy/scriptSource/scriptFile'
        expect(node.children.first.content).to eq 'myScript.groovy'
      end
    end

    context 'bindings' do
      let(:params) { { builders: { system_groovy: { file: 'myScript.groovy', bindings: 'myVar=foo' } } } }

      it 'generates a configuration' do
        node = @n_xml.xpath '//hudson.plugins.groovy.SystemGroovy/bindings'
        expect(node.children.first.content).to eq 'myVar=foo'
      end
    end

    context 'classpath' do
      let(:params) { { builders: { system_groovy: { file: 'myScript.groovy', classpath: '/tmp/myJar.jar' } } } }

      it 'generates a configuration' do
        node = @n_xml.xpath '//hudson.plugins.groovy.SystemGroovy/classpath'
        expect(node.children.first.content).to eq '/tmp/myJar.jar'
      end
    end

    context 'both script and file specified' do
      let(:params) { { builders: { system_groovy: { file: 'myScript.groovy', script: 'print "Hello world"' } } } }

      it 'fails' do
        expect(error).to eq 'Configuration invalid. Both \'script\' and \'file\' keys can not be specified'
      end
    end

    context 'neither script and file specified' do
      let(:params) { { builders: { system_groovy: {} } } }

      it 'fails' do
        expect(error).to eq 'Configuration invalid. At least one of \'script\' and \'file\' keys must be specified'
      end
    end
  end
end
