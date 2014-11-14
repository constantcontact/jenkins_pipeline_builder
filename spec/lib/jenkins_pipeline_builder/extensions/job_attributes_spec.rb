require File.expand_path('../../spec_helper', __FILE__)

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

  after :each do |example|
    name = example.description.gsub ' ', '_'
    File.open("./out/xml/job_attribute_#{name}.xml", 'w') { |f| @n_xml.write_xml_to f }
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
            credentials_id: :creds
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
end
