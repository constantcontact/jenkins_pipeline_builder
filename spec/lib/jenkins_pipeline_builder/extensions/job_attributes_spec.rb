require File.expand_path('../spec_helper', __dir__)

describe 'job_attributes' do
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
    properties = Nokogiri::XML::Builder.new { |xml| xml.properties }
    @n_xml = properties.doc
  end

  after :each do |example|
    name = example.description.tr ' ', '_'
    File.open("./out/xml/job_attribute_#{name}.xml", 'w') { |f| @n_xml.write_xml_to f }
  end

  context 'generic' do
    it 'can register a job_attribute' do
      result = job_attribute do
        name :test_generic
        plugin_id :foo
        xml do
          foo :bar
        end
      end
      puts result.inspect
      JenkinsPipelineBuilder.registry.registry[:job].delete :test_generic
      expect(result).to be true
    end

    it 'fails to register an invalid job_attribute' do
      result = job_attribute do
        name :test_generic
      end
      JenkinsPipelineBuilder.registry.registry[:job].delete :test_generic
      expect(result).to be false
    end
  end

  context 'parameters' do
    let(:params) { { parameters: [{ type: type, name: :foo, description: :desc, default: :default }] } }

    before :each do
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      @parameters = @n_xml.root.children.first
      expect(@parameters.name).to match 'hudson.model.ParametersDefinitionProperty'
    end

    context 'string parameter' do
      let(:type) { 'string' }
      it 'generates correct config' do
        expect(@parameters.to_s).to include 'hudson.model.StringParameterDefinition'
      end
    end

    context 'password parameter' do
      let(:type) { 'password' }
      it 'generates correct config' do
        expect(@parameters.to_s).to include 'hudson.model.PasswordParameterDefinition'
      end
    end

    context 'bool parameter' do
      let(:type) { 'bool' }
      it 'generates correct config' do
        expect(@parameters.to_s).to include 'hudson.model.BooleanParameterDefinition'
      end
    end

    context 'text parameter' do
      let(:type) { 'text' }
      it 'generates correct config' do
        expect(@parameters.to_s).to include 'hudson.model.TextParameterDefinition'
      end
    end

    context 'choice parameter' do
      let(:params) do
        { parameters: [{ type: 'choice', values: %i[foo bar], name: :foo, description: :desc, default: :default }] }
      end

      it 'generates correct config' do
        expect(@parameters.to_s).to include 'hudson.model.ChoiceParameterDefinition'
        expect(@n_xml.root.css('string').map(&:text)).to include 'foo'
        expect(@n_xml.root.css('string').map(&:text)).to include 'bar'
      end
    end

    context 'file parameter' do
      let(:type) { 'file' }
      it 'generates correct config' do
        expect(@parameters.to_s).to include 'hudson.model.FileParameterDefinition'
      end
    end

    context 'defaults to string' do
      let(:type) { 'bad_choice' }
      it 'generates correct config' do
        expect(@parameters.to_s).to include 'hudson.model.StringParameterDefinition'
      end
    end
  end

  context 'name parameter' do
    before :each do
      params = { shared_workspace: { name: :foo } }
      JenkinsPipelineBuilder.registry.registry[:job][:shared_workspace].installed_version = '0'
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      @parameters = @n_xml.root.children.first
      expect(@parameters.name).to match 'org.jenkinsci.plugins.sharedworkspace.SharedWorkspace'
    end

    it 'generates correct config' do
      expect(@parameters.to_s).to include 'name'
    end
  end

  context 'disabled' do
    it 'sets disabled' do
      params = { disabled: true }

      builder = Nokogiri::XML::Builder.new do |xml|
        xml.project do
          xml.disabled
        end
      end
      @n_xml = builder.doc

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml.root.css('disabled').first).to be_truthy
      expect(@n_xml.root.css('disabled').first.content).to eq 'true'
    end
  end

  context 'jdk' do
    it 'sets jdk' do
      params = { jdk: 'JDK-8u45' }

      builder = Nokogiri::XML::Builder.new do |xml|
        xml.project
      end
      @n_xml = builder.doc

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      expect(@n_xml.root.css('jdk').first.content).to eq 'JDK-8u45'
    end
  end

  context 'block_when_downstream_building' do
    it 'sets blockBuildWhenDownstreamBuilding' do
      params = { block_when_downstream_building: 'true' }

      builder = Nokogiri::XML::Builder.new do |xml|
        xml.send('hudson.plugins.promoted__builds.PromotionProcess', 'plugin' => 'promoted-builds@2.27')
      end
      @n_xml = builder.doc

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml.at('blockBuildWhenDownstreamBuilding')).to be_truthy
      expect(@n_xml.at('blockBuildWhenDownstreamBuilding').content).to eq 'true'
    end
  end

  context 'block_when_upstream_building' do
    it 'sets blockBuildWhenUpstreamBuilding' do
      params = { block_when_upstream_building: 'true' }

      builder = Nokogiri::XML::Builder.new do |xml|
        xml.send('hudson.plugins.promoted__builds.PromotionProcess', 'plugin' => 'promoted-builds@2.27')
      end
      @n_xml = builder.doc

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml.at('blockBuildWhenUpstreamBuilding')).to be_truthy
      expect(@n_xml.at('blockBuildWhenUpstreamBuilding').content).to eq 'true'
    end
  end

  context 'is_visible' do
    it 'sets isVisible' do
      params = { is_visible: 'true' }

      builder = Nokogiri::XML::Builder.new do |xml|
        xml.send('hudson.plugins.promoted__builds.PromotionProcess', 'plugin' => 'promoted-builds@2.27')
      end
      @n_xml = builder.doc

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml.at('isVisible')).to be_truthy
    end
  end

  context 'promotion_icon' do
    it 'sets the promotion_icon' do
      params = { promotion_icon: 'gold-e' }

      builder = Nokogiri::XML::Builder.new do |xml|
        xml.send('hudson.plugins.promoted__builds.PromotionProcess', 'plugin' => 'promoted-builds@2.27')
      end
      @n_xml = builder.doc

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml.at('icon')).to be_truthy
      expect(@n_xml.at('icon').content).to eq 'star-gold-e'
    end
  end

  context 'scm params' do
    before :each do
      builder = Nokogiri::XML::Builder.new { |xml| xml.scm }
      @n_xml = builder.doc

      Nokogiri::XML::Builder.with(@n_xml.xpath('//scm').first) do |xml|
        xml.userRemoteConfigs do
          xml.send('hudson.plugins.git.UserRemoteConfig') do
            xml.url 'http://foo.com'
          end
        end
      end
    end
    context '>= 2.0' do
      before :each do
        JenkinsPipelineBuilder.registry.registry[:job][:scm_params].installed_version = '2.0'
      end

      it 'sets the config version' do
        params = { scm_params: { refspec: :bar, remote_name: :foo }, scm_url: 'http://foo.com' }

        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

        scm_config = @n_xml.xpath('//scm').first

        expect(scm_config.css('configVersion').first).to be_truthy
        expect(scm_config.css('configVersion').first.content).to eq '2'
      end

      it 'sets the remote url name all the time' do
        params = { scm_params: {}, scm_url: 'http://foo.com' }

        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

        scm_config = @n_xml.xpath('//scm').first

        expect(
          scm_config.xpath('//scm/userRemoteConfigs/hudson.plugins.git.UserRemoteConfig').first.children.map(&:name)
        ).to_not include 'refspec'
        expect(
          scm_config.xpath('//scm/userRemoteConfigs/hudson.plugins.git.UserRemoteConfig').first.children.map(&:name)
        ).to_not include 'name'
        expect(
          scm_config.xpath('//scm/userRemoteConfigs/hudson.plugins.git.UserRemoteConfig/url').first
        ).to be_truthy
        expect(
          scm_config.xpath('//scm/userRemoteConfigs/hudson.plugins.git.UserRemoteConfig/url').first.content
        ).to eq 'http://foo.com'
      end

      it 'writes a single block if refspec and remote_name are specified' do
        params = { scm_params: { refspec: :bar, remote_name: :foo }, scm_url: 'http://foo.com' }

        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

        remote_config = @n_xml.xpath('//scm/userRemoteConfigs/hudson.plugins.git.UserRemoteConfig').first

        expect(remote_config.name).to match 'hudson.plugins.git.UserRemoteConfig'

        expect(remote_config.css('name').first).to be_truthy
        expect(remote_config.css('refspec').first).to be_truthy

        expect(remote_config.css('name').first.content).to eq 'foo'
        expect(remote_config.css('refspec').first.content).to eq 'bar'
      end

      it 'sets all the options' do
        params = {
          scm_params: {
            changelog_to_branch: {
              remote: 'origin',
              branch: 'pr-1'
            },
            local_branch: :local,
            recursive_update: true,
            excluded_users: :exclude_me,
            included_regions: :included_region,
            excluded_regions: :excluded_region,
            wipe_workspace: true,
            remote_name: :foo,
            refspec: :refspec,
            remote_url: :remote_url,
            credentials_id: :creds,
            skip_tag: true
          },
          scm_url: 'http://foo.com'
        }

        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

        scm_config = @n_xml.xpath('//scm').first

        expect(scm_config.css('compareRemote').first).to be_truthy
        expect(scm_config.css('compareTarget').first).to be_truthy
        expect(scm_config.css('disableSubmodules').first).to be_truthy
        expect(scm_config.css('recursiveSubmodules').first).to be_truthy
        expect(scm_config.css('trackingSubmodules').first).to be_truthy
        expect(scm_config.css('localBranch').first).to be_truthy
        expect(scm_config.css('excludedUsers').first).to be_truthy
        expect(scm_config.css('includedRegions').first).to be_truthy
        expect(scm_config.css('excludedRegions').first).to be_truthy
        expect(scm_config.css('credentialsId').first).to be_truthy
        expect(
          scm_config.xpath('//scm/extensions/hudson.plugins.git.extensions.impl.WipeWorkspace').first
        ).to_not be_nil
        expect(
          scm_config.xpath('//scm/extensions/hudson.plugins.git.extensions.impl.PathRestriction').first
        ).to_not be_nil

        expect(scm_config.css('compareRemote').first.content).to eq 'origin'
        expect(scm_config.css('compareTarget').first.content).to eq 'pr-1'
        expect(scm_config.css('disableSubmodules').first.content).to eq 'false'
        expect(scm_config.css('recursiveSubmodules').first.content).to eq 'true'
        expect(scm_config.css('trackingSubmodules').first.content).to eq 'false'
        expect(scm_config.css('localBranch').first.content).to eq 'local'
        expect(scm_config.css('excludedUsers').first.content).to eq 'exclude_me'
        expect(scm_config.css('includedRegions').first.content).to eq 'included_region'
        expect(scm_config.css('excludedRegions').first.content).to eq 'excluded_region'
        expect(scm_config.css('credentialsId').first.content).to eq 'creds'
        expect(scm_config.css('skipTag').first.content).to eq 'true'
      end
    end

    context '<2.0' do
      before :each do
        JenkinsPipelineBuilder.registry.registry[:job][:scm_params].installed_version = '1.0'
      end

      it 'writes one block when both refspec and remote_name' do
        params = { scm_params: { refspec: :bar, remote_name: :foo }, scm_url: 'http://foo.com' }

        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

        remote_config = @n_xml.root.children.first.children.first

        expect(remote_config.name).to match 'hudson.plugins.git.UserRemoteConfig'

        expect(remote_config.css('name').first).to be_truthy
        expect(remote_config.css('refspec').first).to be_truthy

        expect(remote_config.css('name').first.content).to eq 'foo'
        expect(remote_config.css('refspec').first.content).to eq 'bar'
      end

      it 'using remote_name does not remove the remote url' do
        params = { scm_params: { remote_name: :foo }, scm_url: 'http://foo.com' }

        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

        remote_config = @n_xml.root.children.first.children.first

        expect(remote_config.name).to match 'hudson.plugins.git.UserRemoteConfig'

        expect(remote_config.css('name').first).to be_truthy
        expect(remote_config.css('url').first).to be_truthy

        expect(remote_config.css('name').first.content).to eq 'foo'
        expect(remote_config.css('url').first.content).to eq 'http://foo.com'
      end
    end
  end

  context 'inject_env_vars_pre_scm' do
    before :each do
      JenkinsPipelineBuilder.registry.registry[:job][:inject_env_vars_pre_scm].installed_version = '1.93.1'
    end

    it 'generates correct config' do
      env_vars =  { inject_env_vars_pre_scm: { script_content: 'echo foo' } }
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', env_vars, @n_xml)
      properties = @n_xml.root.children.first
      expect(properties.name).to match 'EnvInjectJobProperty'
      expect(properties.css('scriptContent').first.content).to eq 'echo foo'
    end
  end
end
