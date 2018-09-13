require File.expand_path('../spec_helper', __dir__)

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
    name = example.description.tr ' ', '_'
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
      # This test is pending because the ansicolor wrapper has a property `parameters false` which is intended to
      # indicate that the plugin does not take any parameters. This does not work as expected, however, after
      # updating code to meet updated Rubocop standards
      pending
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

  context 'inject_passwords' do
    before :each do
      JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:inject_passwords].installed_version = '0.0'
    end

    it 'generates correct xml with the old way' do
      wrapper = { wrappers: { inject_passwords: [{ name: 'x', value: 'y' }] } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', wrapper, @n_xml)
      path = '//buildWrappers/EnvInjectPasswordWrapper/passwordEntries/EnvInjectPasswordEntry[last()]/name'
      node = @n_xml.root.xpath(path)
      expect(node.first.content).to eq('x')
    end

    it 'generates correct xml with the new way' do
      wrapper = { wrappers: { inject_passwords: { passwords: [{ name: 'x', value: 'y' }] } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', wrapper, @n_xml)
      path = '//buildWrappers/EnvInjectPasswordWrapper/passwordEntries/EnvInjectPasswordEntry[last()]/name'
      node = @n_xml.root.xpath(path)
      expect(node.first.content).to eq('x')
    end

    it 'generates correct xml without passwords' do
      wrapper = { wrappers: { inject_passwords: { inject_global_passwords: true } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', wrapper, @n_xml)
      path = '//buildWrappers/EnvInjectPasswordWrapper/injectGlobalPasswords'
      node = @n_xml.root.xpath(path)
      expect(node.first.content).to be_truthy
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

  context 'prebuild_cleanup' do
    before :each do
      JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:prebuild_cleanup].installed_version = '0.0'
    end

    it 'generates correct xml' do
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', { wrappers: { prebuild_cleanup: true } }, @n_xml)

      node = @n_xml.root.xpath('//buildWrappers/hudson.plugins.ws__cleanup.PreBuildCleanup')
      expect(node.first).to_not be_nil
    end
  end

  context 'build_timeout' do
    before :each do
      JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:build_timeout].installed_version = '0.0'
    end

    it 'generates the correct tags and values for the Absolute strategy' do
      params = { wrappers: { build_timeout: {
        timeout_strategy: 'Absolute',
        timeout_minutes: '5'
      } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      node = @n_xml.root.xpath('//buildWrappers/hudson.plugins.build__timeout.BuildTimeoutWrapper/strategy')
      expect(node.to_s).to include('AbsoluteTimeOutStrategy')
      expect(node.xpath('timeoutMinutes').first).to_not be_nil
      expect(node.xpath('timeoutMinutes').first.content).to match('5')
    end

    it 'generates the correct tags and values for the Deadline strategy' do
      params = { wrappers: { build_timeout: {
        timeout_strategy: 'Deadline',
        deadline_time: '12:05:12',
        deadline_tolerance: '10'
      } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      node = @n_xml.root.xpath('//buildWrappers/hudson.plugins.build__timeout.BuildTimeoutWrapper/strategy')
      expect(node.to_s).to include('DeadlineTimeOutStrategy')
      expect(node.xpath('deadlineTime').first).to_not be_nil
      expect(node.xpath('deadlineToleranceInMinutes').first).to_not be_nil
      expect(node.xpath('deadlineTime').first.content).to match('12:05:12')
      expect(node.xpath('deadlineToleranceInMinutes').first.content).to match('10')
    end

    it 'generates the correct tags and values for the Elastic strategy' do
      params = { wrappers: { build_timeout: {
        timeout_strategy: 'Elastic',
        timeout_percentage: '150',
        number_of_builds: '5',
        fail_safe_timeout: 'true',
        timeout_minutes: '60'
      } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      node = @n_xml.root.xpath('//buildWrappers/hudson.plugins.build__timeout.BuildTimeoutWrapper/strategy')
      expect(node.to_s).to include('ElasticTimeOutStrategy')
      expect(node.xpath('timeoutPercentage').first).to_not be_nil
      expect(node.xpath('numberOfBuilds').first).to_not be_nil
      expect(node.xpath('failSafeTimeoutDuration').first).to_not be_nil
      expect(node.xpath('timeoutMinutesElasticDefault').first).to_not be_nil
      expect(node.xpath('timeoutPercentage').first.content).to match('150')
      expect(node.xpath('numberOfBuilds').first.content).to match('5')
      expect(node.xpath('failSafeTimeoutDuration').first.content).to match('true')
      expect(node.xpath('timeoutMinutesElasticDefault').first.content).to match('60')
    end

    it 'generates the Likely stuck strategy' do
      params = { wrappers: { build_timeout: { timeout_strategy: 'Likely stuck' } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      node = @n_xml.root.xpath('//buildWrappers/hudson.plugins.build__timeout.BuildTimeoutWrapper/strategy')
      expect(node.to_s).to include('LikelyStuckTimeOutStrategy')
    end

    it 'generates the correct tags for the No Activity strategy' do
      params = { wrappers: { build_timeout: {
        timeout_strategy: 'No Activity',
        timeout_seconds: '180'
      } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      node = @n_xml.root.xpath('//buildWrappers/hudson.plugins.build__timeout.BuildTimeoutWrapper/strategy')
      expect(node.to_s).to include('NoActivityTimeOutStrategy')
      expect(node.xpath('timeoutSecondsString').first).to_not be_nil
      expect(node.xpath('timeoutSecondsString').first.content).to match('180')
    end

    it 'generates the correct tags and values for Time-out variable' do
      params = { wrappers: { build_timeout: { timeout_env_var: '55' } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      node = @n_xml.root.xpath('//buildWrappers/hudson.plugins.build__timeout.BuildTimeoutWrapper/timeoutEnvVar')
      expect(node.first).to_not be_nil
    end

    it 'generates the correct tag for the Abort the build action' do
      params = { wrappers: { build_timeout: { operation: 'Abort' } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      node = @n_xml.root.xpath('//buildWrappers/hudson.plugins.build__timeout.BuildTimeoutWrapper/operationList')
      expect(node.xpath('hudson.plugins.build__timeout.operations.AbortOperation').first).to_not be_nil
    end

    it 'generates the correct tag for the Fail the build action' do
      params = { wrappers: { build_timeout: { operation: 'Fail' } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      node = @n_xml.root.xpath('//buildWrappers/hudson.plugins.build__timeout.BuildTimeoutWrapper/operationList')
      expect(node.xpath('hudson.plugins.build__timeout.operations.FailOperation').first).to_not be_nil
    end

    it 'generates the correct tags for the Writing the build description actions' do
      params = { wrappers: { build_timeout: { operation: 'Writing' } } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      str = 'hudson.plugins.build__timeout.operations.WriteDescriptionOperation'
      node = @n_xml.root.xpath('//buildWrappers/hudson.plugins.build__timeout.BuildTimeoutWrapper/operationList')
      expect(node.xpath(str).first).to_not be_nil
      expect(node.xpath("#{str}/description").first).to_not be_nil
    end
  end
end
