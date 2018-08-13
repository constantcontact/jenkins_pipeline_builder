require File.expand_path('../spec_helper', __dir__)

describe 'promotion_conditions' do
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
    condition = Nokogiri::XML::Builder.new { |xml| xml.conditions }
    @n_xml = condition.doc
  end

  after :each do |example|
    name = example.description.tr ' ', '_'
    require 'fileutils'
    FileUtils.mkdir_p 'out/xml'
    File.open("./out/xml/conditions_#{name}.xml", 'w') { |f| @n_xml.write_xml_to f }
  end

  context 'generic' do
    it 'can register a condition' do
      result = promotion_condition do
        name :test_generic
        plugin_id :foo
        xml do
          foo :bar
        end
      end
      JenkinsPipelineBuilder.registry.registry[:job][:promotion_conditions].delete :test_generic
      expect(result).to be true
    end

    it 'fails to register an invalid condition' do
      result = promotion_condition do
        name :test_generic
      end
      JenkinsPipelineBuilder.registry.registry[:job][:promotion_conditions].delete :test_generic
      expect(result).to be false
    end
  end

  context 'type: manual' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'promoted-builds' => '2.31' }
      )
    end

    it 'generates manual given parameter' do
      params = { promotion_conditions:
              [{ manual: { users: 'unauthorized' } }] }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.ManualCondition/users')
        .text)
        .to eq('unauthorized')
    end

    it 'generates manual defaults' do
      params = { promotion_conditions:
              [{ manual: {} }] }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.ManualCondition/users')
        .text)
        .to eq('')
    end
  end

  context 'type: self_promotion' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'promoted-builds' => '2.31' }
      )
    end

    it 'generates a self promotion given parameters' do
      params = { promotion_conditions:
              [{ self_promotion:
               { even_if_unstable: false } }] }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.SelfPromotionCondition/evenIfUnstable')
        .text)
        .to eq('false')
    end

    it 'generates a self promotion defaults' do
      params = { promotion_conditions: [{ self_promotion: {} }] }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.SelfPromotionCondition/evenIfUnstable')
        .text)
        .to eq('true')
    end
  end

  context 'type: parameterized_self_promotion' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'promoted-builds' => '2.31' }
      )
    end

    it 'generates a parameterized self promotion given parameters' do
      params = { promotion_conditions:
              [{ parameterized_self_promotion:
               { parameter_name: 'SOME_ENV_CHAR', parameter_value: false, even_if_unstable: false } }] }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.ParameterizedSelfPromotionCondition/parameterName')
        .text)
        .to eq('SOME_ENV_CHAR')
      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.ParameterizedSelfPromotionCondition/parameterValue')
        .text)
        .to eq('false')
      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.ParameterizedSelfPromotionCondition/evenIfUnstable')
        .text)
        .to eq('false')
    end

    it 'generates a parameterized self promotion defaults' do
      params = { promotion_conditions:
              [{ parameterized_self_promotion: {} }] }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.ParameterizedSelfPromotionCondition/parameterName')
        .text)
        .to eq('')
      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.ParameterizedSelfPromotionCondition/parameterValue')
        .text).to eq('true')
      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.ParameterizedSelfPromotionCondition/evenIfUnstable')
        .text)
        .to eq('true')
    end
  end

  context 'type: downstream_pass' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'promoted-builds' => '2.31' }
      )
    end

    it 'generates a downstream pass configuration given parameters' do
      params = { promotion_conditions:
              [downstream_pass:
               { jobs: 'Worst-Commit-Ever', even_if_unstable: true }] }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.DownstreamPassCondition/jobs')
        .text)
        .to eq('Worst-Commit-Ever')
      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.DownstreamPassCondition/evenIfUnstable')
        .text)
        .to eq('true')
    end

    it 'generates a downstream pass defaults' do
      params = { promotion_conditions:
              [downstream_pass: {}] }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.DownstreamPassCondition/jobs')
        .text)
        .to eq('{{Example}}-Commit')
      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.DownstreamPassCondition/evenIfUnstable')
        .text)
        .to eq('true')
    end
  end

  context 'type: upstream_promotion' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'promoted-builds' => '2.31' }
      )
    end

    it 'generates a upstream promotion parameters' do
      params = { promotion_conditions:
              [upstream_promotion:
               { promotion_name: 'Never-Promotes' }] }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.UpstreamPromotionCondition/promotionName')
        .text)
        .to eq('Never-Promotes')
    end

    it 'generates a upstream promotion defaults' do
      params = { promotion_conditions:
              [upstream_promotion: {}] }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.UpstreamPromotionCondition/promotionName')
        .text)
        .to eq('01. Staging Promotion')
    end

    it 'generates all condition defaults given no parameters' do
      params = { promotion_conditions:
              [{ manual: {} },
               { self_promotion: {} },
               { parameterized_self_promotion: {} },
               { downstream_pass: {} },
               { upstream_promotion: {} }] }

      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.ManualCondition/users')
        .text)
        .to eq('')
      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.SelfPromotionCondition/evenIfUnstable')
        .text)
        .to eq('true')
      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.ParameterizedSelfPromotionCondition/parameterName')
        .text)
        .to eq('')
      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.ParameterizedSelfPromotionCondition/parameterValue')
        .text)
        .to eq('true')
      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.ParameterizedSelfPromotionCondition/evenIfUnstable')
        .text)
        .to eq('true')
      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.DownstreamPassCondition/jobs')
        .text)
        .to eq('{{Example}}-Commit')
      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.DownstreamPassCondition/evenIfUnstable')
        .text)
        .to eq('true')
      expect(@n_xml
        .at('//hudson.plugins.promoted__builds.conditions.UpstreamPromotionCondition/promotionName')
        .text)
        .to eq('01. Staging Promotion')
    end
  end
end
