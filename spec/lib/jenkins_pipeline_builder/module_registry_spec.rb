require File.expand_path('../spec_helper', __FILE__)

describe JenkinsPipelineBuilder::ModuleRegistry do
  after :each do
    JenkinsPipelineBuilder.registry.clear_versions
  end
  describe '#register' do
    it 'should return item by a specified path' do
      registry = JenkinsPipelineBuilder::ModuleRegistry.new
      set = double
      allow(set).to receive(:name).and_return :foo
      registry.register [:job], set

      expect(registry.get('job/foo').name).to eq :foo
    end

    it 'registered the builders correctly' do
      builders = {
        multi_job: ['0'],
        maven3: ['0'],
        shell_command: ['0'],
        inject_vars_file: ['0'],
        blocking_downstream: ['0'],
        remote_job: ['0'],
        copy_artifact: ['0']
      }
      registry = JenkinsPipelineBuilder.registry.registry
      expect(registry[:job][:builders].size).to eq builders.size
      builders.each do |builder, versions|
        expect(registry[:job][:builders]).to have_key builder

        versions.each do |version|
          expect(registry[:job][:builders][builder]).to have_min_version version
        end
      end
    end

    it 'registered the triggers correctly' do
      triggers = {
        git_push: ['0'],
        scm_polling: ['0'],
        periodic_build: ['0'],
        upstream: ['0']
      }
      registry = JenkinsPipelineBuilder.registry.registry
      expect(registry[:job][:triggers].size).to eq triggers.size
      triggers.each do |trigger, versions|
        expect(registry[:job][:triggers]).to have_key trigger

        versions.each do |version|
          expect(registry[:job][:triggers][trigger]).to have_min_version version
        end
      end
    end
    it 'registered the job_attributes correctly' do
      job_attributes = {
        description: ['0'],
        disabled: ['0'],
        scm_params: ['0'],
        hipchat: ['0'],
        priority: ['0'],
        parameters: ['0'],
        discard_old: ['0'],
        throttle: ['0'],
        prepare_environment: ['0'],
        concurrent_build: ['0'],
        inject_env_vars_pre_scm: ['0'],
        promoted_builds: ['0']
      }
      registry = JenkinsPipelineBuilder.registry.registry
      # There are 4 sub types so, we don't count those
      expect(registry[:job].size - 4).to eq job_attributes.size
      job_attributes.each do |job_attribute, versions|
        expect(registry[:job]).to have_key job_attribute

        versions.each do |version|
          expect(registry[:job][job_attribute]).to have_min_version version
        end
      end
    end
    it 'registered the publishers correctly' do
      publishers = {
        description_setter: ['0'],
        downstream: ['0'],
        hipchat: ['0'],
        git: ['0'],
        junit_result: ['0'],
        coverage_result: ['0'],
        performance_plugin: ['0'],
        post_build_script: ['0'],
        groovy_postbuild: ['0'],
        archive_artifact: ['0'],
        email_notifications: ['0'],
        sonar_result: ['0']
      }
      registry = JenkinsPipelineBuilder.registry.registry
      expect(registry[:job][:publishers].keys).to match_array publishers.keys
      publishers.each do |publisher, versions|
        versions.each do |version|
          expect(registry[:job][:publishers][publisher]).to have_min_version version
        end
      end
    end
    it 'registered the wrappers correctly' do
      wrappers = {
        ansicolor: ['0'],
        timestamp: ['0'],
        rvm: ['0', '0.5'],
        inject_passwords: ['0'],
        inject_env_var: ['0'],
        artifactory: ['0'],
        maven3artifactory: ['0'],
        nodejs: ['0'],
        xvfb: ['0']
      }
      registry = JenkinsPipelineBuilder.registry.registry
      expect(registry[:job][:wrappers].size).to eq wrappers.size
      wrappers.each do |wrapper, versions|
        expect(registry[:job][:wrappers]).to have_key wrapper

        versions.each do |version|
          expect(registry[:job][:wrappers][wrapper]).to have_min_version version
        end
      end
    end
  end
  describe '#initialize' do
  end

  describe '#version' do
    before :all do
      JenkinsPipelineBuilder.credentials = {
        server_ip: '127.0.0.1',
        server_port: 8080,
        username: 'username',
        password: 'password',
        log_location: '/dev/null'
      }
    end

    it 'pulls the version from the registry if it is not memoized' do
      subject.clear_versions
      expect(JenkinsPipelineBuilder).to receive(:debug).and_return false
      expect(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(list_installed: { 'one' => '0.1' })
      subject.versions
    end
  end

  describe '#entries' do
  end

  describe '#get' do
  end

  describe '#get_by_path_collection' do
  end

  describe '#traverse_registry_path' do
  end

  describe '#traverse_registry' do
  end

  describe '#execute_extension' do
  end

  describe 'executing a registry item' do
    before :all do
      class XmlException < StandardError
      end
      class BeforeException < StandardError
      end
      class AfterException < StandardError
      end
      JenkinsPipelineBuilder.credentials = {
        server_ip: '127.0.0.1',
        server_port: 8080,
        username: 'username',
        password: 'password',
        log_location: '/dev/null'
      }
    end

    let(:params) { { wrappers: { test_name: :foo } } }

    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'test_name' => '20.0', 'unorderedTest' => '20.0' })
      @n_xml = Nokogiri::XML::Document.new

      wrapper do
        name :test_name
        plugin_id 'test_name'

        xml do
          true
        end
      end
      expect(JenkinsPipelineBuilder.registry.registry[:job][:wrappers]).to have_key :test_name
      @ext = JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:test_name].extension
    end

    after :each do
      JenkinsPipelineBuilder.registry.registry[:job][:wrappers].delete :test_name
    end

    it 'calls the xml block when executing the item' do
      @ext.xml -> (_) { fail XmlException, 'foo' }

      expect do
        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      end.to raise_error XmlException
    end

    it 'calls the before block' do
      @ext.before -> (_) { fail BeforeException, 'foo' }

      expect do
        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      end.to raise_error BeforeException
    end

    it 'calls the after block' do
      @ext.after -> (_) { fail AfterException, 'foo' }

      expect do
        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      end.to raise_error AfterException
    end

    context 'unordered dsl' do
      let(:params) { { wrappers: { unordered_test: :foo } } }

      after :each do
        JenkinsPipelineBuilder.registry.registry[:job][:wrappers].delete :unordered_test
      end

      it 'works with before first' do
        wrapper do
          name :unordered_test
          plugin_id 'unorderedTest'

          before do
            fail BeforeException, 'foo'
          end

          xml do
            true
          end
        end

        expect(JenkinsPipelineBuilder.registry.registry[:job][:wrappers]).to have_key :unordered_test
        @ext = JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:unordered_test].extension

        expect do
          JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
        end.to raise_error BeforeException
      end

      it 'works with after first' do
        wrapper do
          name :unordered_test
          plugin_id 'unorderedTest'

          after do
            fail AfterException, 'foo'
          end

          xml do
            true
          end
        end

        expect(JenkinsPipelineBuilder.registry.registry[:job][:wrappers]).to have_key :unordered_test
        @ext = JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:unordered_test].extension

        expect do
          JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
        end.to raise_error AfterException
      end

      it 'works with xml first' do
        wrapper do
          name :unordered_test
          plugin_id 'unorderedTest'

          xml do
            fail XmlException, 'foo'
          end

          after do
            true
          end
        end

        expect(JenkinsPipelineBuilder.registry.registry[:job][:wrappers]).to have_key :unordered_test
        @ext = JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:unordered_test].extension

        expect do
          JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
        end.to raise_error XmlException
      end
    end
  end
end
