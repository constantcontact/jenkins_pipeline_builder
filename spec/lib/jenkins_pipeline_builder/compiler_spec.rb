require File.expand_path('../spec_helper', __FILE__)
require 'pp'
describe JenkinsPipelineBuilder::Compiler do
  let(:compiler) { JenkinsPipelineBuilder::Compiler }
  let(:settings_project) { { name: 'DummyPipeline', type: :project, value: { name: 'DummyPipeline', jobs: ['{{name}}-00', { '{{name}}-01' => { job_name: '{{name}}-02' } }] } } }
  let(:settings_global) { { name: 'global', description: 'Do not edit this job through the web!', discard_days: '14', pipeline_repo: 'git@github.com:constantcontact/jenkins_pipeline_builder.git', pipeline_branch: 'master' } }
  let(:settings_bag) { { name: 'DummyPipeline', description: 'Do not edit this job through the web!', discard_days: '14', pipeline_repo: 'git@github.com:constantcontact/jenkins_pipeline_builder.git', pipeline_branch: 'master' } }
  let(:job0) { { name: '{{name}}-00', description: '{{description}}', scm_provider: 'git', scm_url: '{{pipeline_repo}}', scm_branch: '{{pipeline_branch}}', scm_params: { remote_name: 'origin', skip_tag: true }, wrappers: [{ ansicolor: true }], builders: [{ shell_command: "echo 'Running {{name}}'\necho 'About to run {{job@{{name}}-01}}'\n" }], publishers: [{ downstream: { project: '{{job@{{name}}-01}}' } }] } }
  let(:job0_compiled) { { name: 'DummyPipeline-00', description: 'Do not edit this job through the web!', scm_provider: 'git', scm_url: 'git@github.com:constantcontact/jenkins_pipeline_builder.git', scm_branch: 'master', scm_params: { remote_name: 'origin', skip_tag: true }, wrappers: [{ ansicolor: true }], builders: [{ shell_command: "echo 'Running DummyPipeline'\necho 'About to run DummyPipeline-02'\n" }], publishers: [{ downstream: { project: 'DummyPipeline-02' } }] } }
  let(:job2) { { name: '{{name}}-02', description: '{{description}}', scm_provider: 'git', scm_url: '{{pipeline_repo}}', scm_branch: '{{pipeline_branch}}', scm_params: { remote_name: 'origin', skip_tag: true }, wrappers: [{ ansicolor: true }], builders: [{ shell_command: "echo 'Running {{name}}'" }] } }
  let(:job2_compiled) { { name: 'DummyPipeline-02', description: 'Do not edit this job through the web!', scm_provider: 'git', scm_url: 'git@github.com:constantcontact/jenkins_pipeline_builder.git', scm_branch: 'master', scm_params: { remote_name: 'origin', skip_tag: true }, wrappers: [{ ansicolor: true }], builders: [{ shell_command: "echo 'Running DummyPipeline'" }] } }
  let(:job_collection) { { '{{name}}-00' => { name: '{{name}}-00', type: :job, value: { name: '{{name}}-00', description: '{{description}}', scm_provider: 'git', scm_url: '{{pipeline_repo}}', scm_branch: '{{pipeline_branch}}', scm_params: { remote_name: 'origin', skip_tag: true }, wrappers: [{ ansicolor: true }], builders: [{ shell_command: "echo 'Running {{name}}'\necho 'About to run {{job@{{name}}-01}}'\n" }], publishers: [{ downstream: { project: '{{job@{{name}}-01}}' } }] } }, '{{name}}-01' => { name: '{{name}}-01', type: :job, value: { name: '{{name}}-02', description: '{{description}}', scm_provider: 'git', scm_url: '{{pipeline_repo}}', scm_branch: '{{pipeline_branch}}', scm_params: { remote_name: 'origin', skip_tag: true }, wrappers: [{ ansicolor: true }], builders: [{ shell_command: "echo 'Running {{name}}'" }] }, job_name: '{{name}}-02' }, 'global' => { name: 'global', type: :defaults, value: { name: 'global', description: 'Do not edit this job through the web!', discard_days: '14', pipeline_repo: 'git@github.com:constantcontact/jenkins_pipeline_builder.git', pipeline_branch: 'master' } }, 'DummyPipeline' => { name: 'DummyPipeline', type: :project, value: { name: 'DummyPipeline', jobs: [{ '{{name}}-00' => {}, result: { name: 'DummyPipeline-00', description: 'Do not edit this job through the web!', scm_provider: 'git', scm_url: 'git@github.com:constantcontact/jenkins_pipeline_builder.git', scm_branch: 'master', scm_params: { remote_name: 'origin', skip_tag: true }, wrappers: [{ ansicolor: true }], builders: [{ shell_command: "echo 'Running DummyPipeline'\necho 'About to run DummyPipeline-02'\n" }], publishers: [{ downstream: { project: 'DummyPipeline-02' } }] } }, { '{{name}}-01' => { job_name: '{{name}}-02' } }] }, settings: { name: 'DummyPipeline', description: 'Do not edit this job through the web!', discard_days: '14', pipeline_repo: 'git@github.com:constantcontact/jenkins_pipeline_builder.git', pipeline_branch: 'master' } } } }

  describe '#get_settings_bag' do
    it 'merge settings' do
      settings = compiler.get_settings_bag(settings_project, settings_global)
      expect(settings).to eq(settings_bag)
    end
  end

  describe '#compile' do
    it 'compile a job with a name change' do
      result = compiler.compile(job2, settings_bag, job_collection)
      expect(result[1]).to eq(job2_compiled)
    end
    it 'compile a job with a downstream name change' do
      result = compiler.compile(job0, settings_bag, job_collection)
      expect(result[1]).to eq(job0_compiled)
    end
  end
end
