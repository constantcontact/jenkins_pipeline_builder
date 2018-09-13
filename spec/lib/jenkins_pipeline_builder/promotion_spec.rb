require File.expand_path('spec_helper', __dir__)

describe JenkinsPipelineBuilder::Promotion do
  before :all do
    JenkinsPipelineBuilder.credentials = {
      server_ip: '127.0.0.1',
      server_port: 8080,
      username: 'username',
      password: 'password',
      log_location: '/dev/null'
    }
    generator = JenkinsPipelineBuilder.generator
    @promotions = JenkinsPipelineBuilder::Promotion.new(generator)
  end

  before :each do
    allow(JenkinsPipelineBuilder).to receive(:logger).and_return double(
      debug: true,
      info: true,
      warn: true,
      error: true,
      fatal: true
    )
  end

  describe '#create' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'promoted-builds' => '2.31', 'parameterized-trigger' => '20.0' }
      )
      condition = Nokogiri::XML::Builder.new { |xml| xml.conditions }
      @n_xml = condition.doc
    end

    it 'generates correct xml given parameters' do
      params = { name: 'SamplePipeline Stage Promotion',
                 promotion_description: 'Describe the promotion process in play',
                 block_when_downstream_building: false,
                 block_when_upstream_building: false,
                 icon: 'Gold star',
                 conditions: [
                   { manual: { users: 'authorized' } },
                   { self_promotion: { even_if_unstable: true } },
                   { parameterized_self_promotion: {
                     parameter_name: 'SOME_ENV_VAR', parameter_value: true, even_if_unstable: true
                   } },
                   { downstream_pass: { jobs: 'SamplePipeline-10-Commit', even_if_unstable: true } },
                   { upstream_promotion: { promotion_name: 'SamplePipeline Staging Promotion' } }
                 ],
                 build_steps: [
                   { triggered_job: {
                     name: 'SamplePipeline-30-Release',
                     block_condition: { build_step_failure_threshold: 'FAILURE',
                                        failure_threshold: 'FAILURE',
                                        unstable_threshold: 'UNSTABLE' },
                     build_parameters: { current: true }
                   } },
                   { keep_builds_forever: { value: true } }
                 ] }

      @n_xml = @promotions.create(params, 'Random associated job name')

      expect(@n_xml).to include 'conditions'
      expect(@n_xml).to include 'buildSteps'
      expect(@n_xml).to include 'hudson.plugins.promoted__builds.PromotionProcess plugin="promoted-builds@2.27"'
      expect(@n_xml).to include 'hudson.plugins.parameterizedtrigger.TriggerBuilder plugin="parameterized-trigger@2.31"'
      expect(@n_xml).to include 'hudson.plugins.parameterizedtrigger.BlockableBuildTriggerConfig'
      expect(@n_xml).to include 'configs'
      expect(@n_xml).to include 'projects'
      expect(@n_xml).to include 'triggerWithNoParameters'
      expect(@n_xml).to include 'block'
      expect(@n_xml).to include 'buildStepFailureThreshold'
      expect(@n_xml).to include 'name'
      expect(@n_xml).to include 'ordinal'
      expect(@n_xml).to include 'color'
      expect(@n_xml).to include 'completeBuild'
      expect(@n_xml).to include 'unstableThreshold'
      expect(@n_xml).to include 'failureThreshold'
      expect(@n_xml).to include 'buildAllNodesWithLabel'
      expect(@n_xml).to include 'hudson.plugins.promoted__builds.KeepBuildForeverAction'
    end

    it 'fails if prom_to_xml fails' do
      expect(@promotions).to receive(:prom_to_xml).ordered.and_return [false, 'FAILURE']
      expect(@promotions.create('', '')).to eq [false, 'FAILURE']
    end
  end
end
