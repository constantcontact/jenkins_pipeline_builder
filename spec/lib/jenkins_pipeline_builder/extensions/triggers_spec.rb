require File.expand_path('../spec_helper', __dir__)

describe 'triggers' do
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
    trigger = Nokogiri::XML::Builder.new { |xml| xml.triggers }
    @n_xml = trigger.doc
  end

  after :each do |example|
    name = example.description.tr ' ', '_'
    require 'fileutils'
    FileUtils.mkdir_p 'out/xml'
    File.open("./out/xml/trigger_#{name}.xml", 'w') { |f| @n_xml.write_xml_to f }
  end

  context 'generic' do
    it 'can register a trigger' do
      result = trigger do
        name :test_generic
        plugin_id :foo
        xml do
          foo :bar
        end
      end
      JenkinsPipelineBuilder.registry.registry[:job][:triggers].delete :test_generic
      expect(result).to be true
    end

    it 'fails to register an invalid trigger' do
      result = trigger do
        name :test_generic
      end
      JenkinsPipelineBuilder.registry.registry[:job][:triggers].delete :test_generic
      expect(result).to be false
    end
  end

  context 'upstream' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'jenkins-multijob-plugin' => '20.0' }
      )
    end

    it 'generates an unstable configuration' do
      params = { triggers: { upstream: { status: 'unstable' } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      trigger = @n_xml.root.children.first
      expect(trigger.name).to match 'jenkins.triggers.ReverseBuildTrigger'
      expect(trigger.css('name').first.content).to match 'UNSTABLE'
    end

    it 'generates an failed configuration' do
      params = { triggers: { upstream: { status: 'failed' } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      trigger = @n_xml.root.children.first
      expect(trigger.name).to match 'jenkins.triggers.ReverseBuildTrigger'
      expect(trigger.css('name').first.content).to match 'FAILURE'
    end

    it 'generates an successful configuration' do
      params = { triggers: { upstream: { status: 'successful_this_is_an_else' } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      trigger = @n_xml.root.children.first
      expect(trigger.name).to match 'jenkins.triggers.ReverseBuildTrigger'
      expect(trigger.css('name').first.content).to match 'SUCCESS'
    end
  end
end
