require File.expand_path('../../spec_helper', __FILE__)

describe 'publishers' do
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
    builder = Nokogiri::XML::Builder.new { |xml| xml.publishers }
    @n_xml = builder.doc
  end

  after :each do |example|
    name = example.description.gsub ' ', '_'
    File.open("./out/xml/publisher_#{name}.xml", 'w') { |f| @n_xml.write_xml_to f }
  end

  context 'sonar publisher' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'sonar' => '20.0' })
    end

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

    it 'populates root pom' do
      params = { publishers: { sonar_result: { root_pom: 'project_war/pom.xml' } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      sonar_nodes = @n_xml.root.children.first.children
      root_pom = sonar_nodes.select { |node| node.name == 'rootPom' }
      expect(root_pom.first.content).to match 'project_war/pom.xml'
    end
  end

  context 'description_setter' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'description-setter' => '20.0' })
    end
    it 'generates a configuration' do
      params = { publishers: { description_setter: {} } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      publisher = @n_xml.root.children.first
      expect(publisher.name).to match 'hudson.plugins.descriptionsetter.DescriptionSetterPublisher'
    end
  end

  context 'downstream' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'parameterized-trigger' => '20.0'
    })
    end

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

  context 'cobertura_report' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'cobertura' => '20.0'
    })
    end
    it 'generates a configuration' do
      params = { publishers: { cobertura_report: {} } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      publisher = @n_xml.root.children.first
      expect(publisher.name).to match 'hudson.plugins.cobertura.CoberturaPublisher'
      expect(publisher.children.map(&:name)).to_not include 'send_metric_targets'
      expect(publisher.to_xml).to include 'hudson.plugins.cobertura.targets.CoverageMetric'
    end
  end

  context 'email_ext' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'email-ext' => '20.0'
    })
    end
    it 'generates a configuration' do
      params = { publishers: { email_ext: { triggers: [{ type: :first_failure }] } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      publisher = @n_xml.root.children.first
      expect(publisher.name).to match 'hudson.plugins.emailext.ExtendedEmailPublisher'
      expect(publisher.children.map(&:name)).to_not include 'trigger_defaults'
      expect(publisher.to_xml).to include 'FirstFailureTrigger'
    end
  end

  context 'hipchat' do
    context '0.1.9' do
      before :each do
        allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
          list_installed: { 'hipchat' => '0.1.9' })
      end
      it 'generates a configuration' do
        params = { publishers: { hipchat: {} } }
        hipchat = JenkinsPipelineBuilder.registry.registry[:job][:publishers][:hipchat]
        expect(hipchat.extension.min_version).to eq '0.1.9'

        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

        publisher = @n_xml.root.children.first
        expect(publisher.name).to match 'jenkins.plugins.hipchat.HipChatNotifier'
        children = publisher.children.map(&:name)
        expect(children).to include 'token'
        expect(children).to include 'room'
        expect(children).to include 'startNotification'
        expect(children).to include 'notifySuccess'
        expect(children).to include 'completeJobMessage'
      end
    end

    context '0' do
      before :each do
        expect(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
          list_installed: { 'hipchat' => '0'
        })
        puts JenkinsPipelineBuilder.registry.versions
      end

      it 'generates a configuration' do
        expect(JenkinsPipelineBuilder.registry.registry[:job][:publishers][:hipchat].extension.min_version).to eq '0'
        params = { publishers: { hipchat: {} } }

        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

        publisher = @n_xml.root.children.first
        expect(publisher.name).to match 'jenkins.plugins.hipchat.HipChatNotifier'
        children = publisher.children.map(&:name)
        expect(children).to include 'jenkinsUrl'
        expect(children).to include 'room'
        expect(children).to include 'authToken'
      end
    end
  end

  context 'git' do
    it 'generates a configuration'
  end

  context 'junit_result' do
    it 'generates a configuration'
  end

  context 'coverage_result' do
    it 'generates a configuration'
  end

  context 'post_build_script' do
    it 'generates a configuration'
  end

  context 'groovy_postbuild' do
    it 'generates a configuration'
  end

  context 'archive_artifact' do
    it 'generates a configuration'
  end

  context 'email_notification' do
    it 'generates a configuration'
  end
end
