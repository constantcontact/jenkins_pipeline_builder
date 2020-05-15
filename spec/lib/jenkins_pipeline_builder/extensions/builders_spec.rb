require File.expand_path('../spec_helper', __dir__)

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
    params = {}

    before :each do
      params = { builders: { multi_job: { phases: { foo: { jobs:
        [{
          name: 'foo'
        }] } } } } }
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'jenkins-multijob-plugin' => '20.0' }
      )
    end

    it 'generates a configuration' do
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      builder = @n_xml.root.children.first
      expect(builder.name).to match 'com.tikal.jenkins.plugins.multijob.MultiJobBuilder'
    end

    it 'generates a jobName' do
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//jobName'
      expect(node.text).to eq 'foo'
    end

    it 'generates buildOnlyIfSCMChanges flag and sets to parameter' do
      params = { builders: { multi_job: { phases: { foo: { jobs:
        [{
          name: 'foo',
          build_only_if_scm_changes: true
        }] } } } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//buildOnlyIfSCMChanges'
      expect(node.text).to eq 'true'
    end

    it 'generates buildOnlyIfSCMChanges flag and sets to default' do
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//buildOnlyIfSCMChanges'
      expect(node.text).to eq 'false'
    end

    it 'generates disableJob flag and sets to parameter' do
      params = { builders: { multi_job: { phases: { foo: { jobs:
        [{
          name: 'foo',
          disable_job: true
        }] } } } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//disableJob'
      expect(node.text).to eq 'true'
    end

    it 'generates disableJob flag and sets to default' do
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//disableJob'
      expect(node.text).to eq 'false'
    end

    it 'generates maxRetries tag' do
      params = { builders: { multi_job: { phases: { foo: { jobs:
        [{
          name: 'foo',
          max_retries: 1
        }] } } } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//maxRetries'
      expect(node.text).to eq '1'
    end

    it 'generates enableRetryStrategy tag and sets to default' do
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//enableRetryStrategy'
      expect(node.text).to eq 'false'
    end

    it 'provides job specific config' do
      params = { builders: { multi_job: { phases: { foo: { jobs:
        [{
          name: 'foo',
          config:
            {
              predefined_build_parameters: 'bar',
              properties_file: { file: 'props', skip_if_missing: true }
            }
        }] } } } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      node = @n_xml.xpath '//hudson.plugins.parameterizedtrigger.PredefinedBuildParameters'
      expect(node.children.first.content).to eq 'bar'

      node = @n_xml.xpath '//hudson.plugins.parameterizedtrigger.FileBuildParameters/propertiesFile'
      expect(node.children.first.content).to eq 'props'

      node = @n_xml.xpath '//hudson.plugins.parameterizedtrigger.FileBuildParameters/failTriggerOnMissing'
      expect(node.children.first.content).to eq 'true'
    end

    it 'generates conditional job tag' do
      condition = '1+1==2'
      params = { builders: [{ multi_job: { phases: { foo: { jobs:
        [{
          name: 'foo',
          condition: condition,
          apply_condition_only_if: false
        }] } } } }] }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      node = @n_xml.xpath '//enableCondition'
      expect(node.children.first.content).to eq 'true'

      node = @n_xml.xpath '//condition'
      expect(node.children.first.content).to eq condition

      node = @n_xml.xpath '//applyConditionOnlyIfNoSCMChanges'
      expect(node.children.first.content).to eq 'false'
    end

    it 'generates abort all other jobs tag' do
      params = { builders: [{ multi_job: { phases: { foo: { jobs:
        [{
          name: 'foo',
          abort_all_job: true
        }] } } } }] }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//abortAllJob'
      expect(node.children.first.content).to eq 'true'
    end

    it 'generates abort all other jobs tag and sets to default' do
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//abortAllJob'
      expect(node.children.first.content).to eq 'false'
    end

    it 'generates current job parameters with parameters' do
      params = { builders: [{ multi_job: { phases: { foo: { jobs:
        [{
          name: 'foo',
          current_params: true
        }] } } } }] }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//currParams'
      expect(node.children.first.content).to eq 'true'
    end

    it 'generates current job parameters and sets to default' do
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//currParams'
      expect(node.children.first.content).to eq 'false'
    end

    it 'generates continuation condition tag with parameter' do
      params = { builders: [{ multi_job: { phases: { foo: {
        jobs: [{ name: 'foo' }],
        continue_condition: 'ALWAYS'
      } } } }] }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//continuationCondition'
      expect(node.children.first.content).to eq 'ALWAYS'
    end

    it 'generates continuation condition tag and sets to default' do
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//continuationCondition'
      expect(node.children.first.content).to eq 'SUCCESSFUL'
    end

    it 'generates execution type tag with parameter' do
      params = { builders: [{ multi_job: { phases: { foo: {
        jobs: [{ name: 'foo' }],
        execution_type: 'SEQUENTIALLY'
      } } } }] }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//executionType'
      expect(node.children.first.content).to eq 'SEQUENTIALLY'
    end

    it 'generates execution type tag and sets to default' do
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      node = @n_xml.xpath '//executionType'
      expect(node.children.first.content).to eq 'PARALLEL'
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

  context 'sonar_standalone' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'sonar' => '2.1' }
      )
    end

    it 'generates a configuration' do
      params = { builders: { sonar_standalone: { pathToProjectProperties: 'sonar-project.properties' } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      builder = @n_xml.root.children.first
      expect(builder.name).to match 'hudson.plugins.sonar.SonarRunnerBuilder'
      expect(@n_xml.root.css('project').first.text).to eq 'sonar-project.properties'
      expect(@n_xml.root.css('jdk').first.text).to eq '(Inherit From Job)'
    end

    it 'allows the JDK default to be overriden' do
      params = { builders: { sonar_standalone: { jdk: '9', pathToProjectProperties: 'sonar-project.properties' } } }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml.root.css('jdk').first.text).to eq '9'
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
      rescue RuntimeError => e
        puts "Caught error #{e}"
        error = e.to_s
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

  context 'nodejs_script' do
    let(:params) do
      {
        builders: {
          nodejs_script: {
            script: 'console.log("Hello World")', nodeJS_installation_name: 'Node_6.9.2'
          }
        }
      }
    end

    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'nodejs' => '0.2.2' }
      )
      begin
        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      rescue RuntimeError => e
        puts 'Runtime Error: ' + e.to_s
      end
      builder = @n_xml.root.children.first
      expect(builder.name).to match 'jenkins.plugins.nodejs.NodeJsCommandInterpreter'
    end

    it 'generates a configuration' do
      command = @n_xml.xpath '//jenkins.plugins.nodejs.NodeJsCommandInterpreter/command'
      install_version = @n_xml.xpath '//jenkins.plugins.nodejs.NodeJsCommandInterpreter/nodeJSInstallationName'
      expect(command.children.first.content).to eq 'console.log("Hello World")'
      expect(install_version.children.first.content).to eq 'Node_6.9.2'
    end
  end

  context 'conditional_multijob_step' do
    let(:default_params) do
      {
        builders: {
          conditional_multijob_step: {
            conditional_shell: 'echo',
            phases: {
              myphase1: {
                jobs: [
                  {
                    name: 'myjob1',
                    config: {
                      predefined_build_parameters: 'X=Y\nR=Z'
                    }
                  }
                ]
              }
            }
          }
        }
      }
    end
    let(:base_x_path) do
      '//org.jenkinsci.plugins.conditionalbuildstep.singlestep.SingleConditionalBuilder'
    end
    let(:build_step_x_path) do
      "#{base_x_path}/buildStep"
    end
    let(:phase_jobs_x_path) do
      "#{build_step_x_path}/phaseJobs/com.tikal.jenkins.plugins.multijob.PhaseJobsConfig"
    end

    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'conditional-buildstep' => '1.3.3' }
      )
    end

    it 'generates a configuration' do
      params = default_params
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      builder = @n_xml.root.children.first
      expect(builder.name).to match 'org.jenkinsci.plugins.conditionalbuildstep.singlestep.SingleConditionalBuilder'
      command = @n_xml.xpath base_x_path
      expect(command.first.content).to match 'echo'
    end

    it 'creates a phase' do
      params = default_params
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      phase_name = @n_xml.xpath "#{build_step_x_path}/phaseName"
      expect(phase_name.first.content).to match 'myphase1'
      phase_continue = @n_xml.xpath "#{build_step_x_path}/continuationCondition"
      expect(phase_continue.first.content).to match 'SUCCESSFUL'
    end

    it 'creates a job' do
      params = default_params

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      job_name = @n_xml.xpath "#{phase_jobs_x_path}/jobName"
      expect(job_name.first.content).to match 'myjob1'
      curr_params = @n_xml.xpath "#{phase_jobs_x_path}/currParams"
      expect(curr_params.first.content).to match 'false'
      exposed_scm = @n_xml.xpath "#{phase_jobs_x_path}/exposedSCM"
      expect(exposed_scm.first.content).to match 'false'
      predefined_params = @n_xml.xpath "#{phase_jobs_x_path}/"\
        'configs/hudson.plugins.parameterizedtrigger.PredefinedBuildParameters'
      expect(predefined_params.first.content).to match 'X=Y\nR=Z'
      kill_phase_cond = @n_xml.xpath "#{phase_jobs_x_path}/killPhaseOnJobResultCondition"
      expect(kill_phase_cond.first.content).to match 'FAILURE'
    end

    # TODO: More tests
  end
end
