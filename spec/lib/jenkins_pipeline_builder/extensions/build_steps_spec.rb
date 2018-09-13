require File.expand_path('../spec_helper', __dir__)

describe 'build_steps' do
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
    builder = Nokogiri::XML::Builder.new { |xml| xml.buildSteps }
    @n_xml = builder.doc
  end

  after :each do |example|
    name = example.description.tr ' ', '_'
    require 'fileutils'
    FileUtils.mkdir_p 'out/xml'
    File.open("./out/xml/build_steps_#{name}.xml", 'w') { |f| @n_xml.write_xml_to f }
  end

  context 'generic' do
    it 'can register a build_step' do
      result = build_step do
        name :test_generic
        plugin_id :foo
        xml do
          foo :bar
        end
      end
      JenkinsPipelineBuilder.registry.registry[:job][:build_steps].delete :test_generic
      expect(result).to be true
    end

    it 'fails to register an invalid build_step' do
      result = build_step do
        name :test_generic
      end
      JenkinsPipelineBuilder.registry.registry[:job][:build_steps].delete :test_generic
      expect(result).to be false
    end
  end

  context 'triggered_jobs' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'promoted-builds' => '2.31', 'parameterized-trigger' => '20.0' }
      )
    end

    it 'generates a configuration with standard defaults' do
      params = { build_steps: { triggered_job:
               { name: 'ReleaseBuild' } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      xml_from_jenkins = parse_expectation_xml(
        "<buildSteps>
          <hudson.plugins.parameterizedtrigger.TriggerBuilder plugin='parameterized-trigger@2.31'>
            <configs>
              <hudson.plugins.parameterizedtrigger.BlockableBuildTriggerConfig>
                <configs class='empty-list' />
                <projects>ReleaseBuild</projects>
                <condition>ALWAYS</condition>
                <triggerWithNoParameters>false</triggerWithNoParameters>
                <block>
                  <buildStepFailureThreshold>
                    <name>FAILURE</name>
                    <ordinal>2</ordinal>
                    <color>RED</color>
                    <completeBuild>true</completeBuild>
                  </buildStepFailureThreshold>
                  <unstableThreshold>
                    <name>UNSTABLE</name>
                    <ordinal>1</ordinal>
                    <color>YELLOW</color>
                    <completeBuild>true</completeBuild>
                  </unstableThreshold>
                  <failureThreshold>
                    <name>FAILURE</name>
                    <ordinal>2</ordinal>
                    <color>RED</color>
                    <completeBuild>true</completeBuild>
                  </failureThreshold>
                </block>
                <buildAllNodesWithLabel>false</buildAllNodesWithLabel>
              </hudson.plugins.parameterizedtrigger.BlockableBuildTriggerConfig>
            </configs>
          </hudson.plugins.parameterizedtrigger.TriggerBuilder>
        </buildSteps>"
      )

      expect(@n_xml).to be_equivalent_to(xml_from_jenkins)
    end

    it 'generates no block conditions when set to false' do
      params = { build_steps: { triggered_job:
               { name: 'ReleaseBuild', block_condition: false } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      xml_from_jenkins = parse_expectation_xml(
        "<buildSteps>
          <hudson.plugins.parameterizedtrigger.TriggerBuilder plugin='parameterized-trigger@2.31'>
            <configs>
              <hudson.plugins.parameterizedtrigger.BlockableBuildTriggerConfig>
              <configs class='empty-list'/>
              <projects>ReleaseBuild</projects>
              <condition>ALWAYS</condition>
              <triggerWithNoParameters>false</triggerWithNoParameters>
              <buildAllNodesWithLabel>false</buildAllNodesWithLabel>
            </hudson.plugins.parameterizedtrigger.BlockableBuildTriggerConfig>
            </configs>
          </hudson.plugins.parameterizedtrigger.TriggerBuilder>
        </buildSteps>"
      )

      expect(@n_xml).to be_equivalent_to(xml_from_jenkins)
    end

    it 'generates build state with current parameters' do
      params = { build_steps: { triggered_job:
               { name: 'ReleaseBuild', build_parameters: [:current] } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at_xpath("//buildSteps/
        hudson.plugins.parameterizedtrigger.TriggerBuilder/
        configs/
        hudson.plugins.parameterizedtrigger.BlockableBuildTriggerConfig/
        configs/
        hudson.plugins.parameterizedtrigger.CurrentBuildParameters"))
        .not_to equal(nil)
    end

    it 'generates build state with predefined parameters' do
      params = { build_steps: { triggered_job:
               { name: 'ReleaseBuild', build_parameters: [[:predefined, { x: 1, 'y' => 2 }]] } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at_xpath("//buildSteps/
        hudson.plugins.parameterizedtrigger.TriggerBuilder/
        configs/
        hudson.plugins.parameterizedtrigger.BlockableBuildTriggerConfig/
        configs/
        hudson.plugins.parameterizedtrigger.PredefinedBuildParameters/
        properties").text)
        .to eq('X=1 Y=2')
    end

    it 'generates build state with file parameters' do
      params = { build_steps: { triggered_job:
               { name: 'ReleaseBuild', build_parameters: [[:file, '/usr/local/params']] } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at_xpath("//buildSteps/
        hudson.plugins.parameterizedtrigger.TriggerBuilder/
        configs/
        hudson.plugins.parameterizedtrigger.BlockableBuildTriggerConfig/
        configs/
        hudson.plugins.parameterizedtrigger.FileBuildParameters/
        propertiesFile").text)
        .to eq('/usr/local/params')
    end
  end

  context 'keep_builds_forever' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'promoted-builds' => '2.31' }
      )
    end

    it 'generates the keep_builds_forever tag' do
      params = { build_steps: { keep_builds_forever: true } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at_xpath("//buildSteps/
        hudson.plugins.promoted__builds.KeepBuildForeverAction"))
        .to_not eq(nil)
    end
  end
end
