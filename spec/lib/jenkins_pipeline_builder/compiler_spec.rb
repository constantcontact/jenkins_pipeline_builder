require File.expand_path('../spec_helper', __FILE__)
describe JenkinsPipelineBuilder::Compiler do
  before :all do
    JenkinsPipelineBuilder.credentials = {
      server_ip: '127.0.0.1',
      server_port: 8080,
      username: 'username',
      password: 'password',
      log_location: '/dev/null'
    }
  end
  let(:generator) { double(job_collection: double(collection: job_collection)) }
  let(:compiler) { JenkinsPipelineBuilder::Compiler.new generator }
  let(:settings_global) { { name: 'global', description: 'Do not edit this job through the web!', discard_days: '14', pipeline_repo: 'git@github.com:constantcontact/jenkins_pipeline_builder.git', pipeline_branch: 'master' } }
  let(:settings_bag) { { name: 'DummyPipeline', description: 'Do not edit this job through the web!', discard_days: '14', pipeline_repo: 'git@github.com:constantcontact/jenkins_pipeline_builder.git', pipeline_branch: 'master' } }
  let(:job_collection) { { '{{name}}-00' => { name: '{{name}}-00', type: :job, value: { name: '{{name}}-00', description: '{{description}}', scm_provider: 'git', scm_url: '{{pipeline_repo}}', scm_branch: '{{pipeline_branch}}', scm_params: { remote_name: 'origin', skip_tag: true }, wrappers: [{ ansicolor: true }], builders: [{ shell_command: "echo 'Running {{name}}'\necho 'About to run {{job@{{name}}-01}}'\n" }], publishers: [{ downstream: { project: '{{job@{{name}}-01}}' } }] } }, '{{name}}-01' => { name: '{{name}}-01', type: :job, value: { name: '{{name}}-02', description: '{{description}}', scm_provider: 'git', scm_url: '{{pipeline_repo}}', scm_branch: '{{pipeline_branch}}', scm_params: { remote_name: 'origin', skip_tag: true }, wrappers: [{ ansicolor: true }], builders: [{ shell_command: "echo 'Running {{name}}'" }] }, job_name: '{{name}}-02' }, 'global' => { name: 'global', type: :defaults, value: { name: 'global', description: 'Do not edit this job through the web!', discard_days: '14', pipeline_repo: 'git@github.com:constantcontact/jenkins_pipeline_builder.git', pipeline_branch: 'master' } }, 'DummyPipeline' => { name: 'DummyPipeline', type: :project, value: { name: 'DummyPipeline', jobs: [{ '{{name}}-00' => {}, result: { name: 'DummyPipeline-00', description: 'Do not edit this job through the web!', scm_provider: 'git', scm_url: 'git@github.com:constantcontact/jenkins_pipeline_builder.git', scm_branch: 'master', scm_params: { remote_name: 'origin', skip_tag: true }, wrappers: [{ ansicolor: true }], builders: [{ shell_command: "echo 'Running DummyPipeline'\necho 'About to run DummyPipeline-02'\n" }], publishers: [{ downstream: { project: 'DummyPipeline-02' } }] } }, { '{{name}}-01' => { job_name: '{{name}}-02' } }] }, settings: { name: 'DummyPipeline', description: 'Do not edit this job through the web!', discard_days: '14', pipeline_repo: 'git@github.com:constantcontact/jenkins_pipeline_builder.git', pipeline_branch: 'master' } } } }

  describe '#get_settings_bag' do
    it 'merge settings' do
      settings_project = {
        name: 'DummyPipeline',
        type: :project,
        value: {
          name: 'DummyPipeline',
          jobs: [
            '{{name}}-00',
            { '{{name}}-01' => { job_name: '{{name}}-02' }
          }
          ]
        }
      }
      settings = compiler.get_settings_bag(settings_project, settings_global)
      expect(settings).to eq(settings_bag)
    end
  end

  describe '#compile' do
    it 'compiles a job with a name change' do
      job = {
        name: '{{name}}-02',
        description: '{{description}}',
        scm_provider: 'git',
        scm_url: '{{pipeline_repo}}',
        scm_branch: '{{pipeline_branch}}',
        scm_params: {
          remote_name: 'origin',
          skip_tag: true
        },
        wrappers: [{ ansicolor: true }],
        builders: [{ shell_command: "echo 'Running {{name}}'" }]
      }
      job_compiled = {
        name: 'DummyPipeline-02',
        description: 'Do not edit this job through the web!',
        scm_provider: 'git',
        scm_url: 'git@github.com:constantcontact/jenkins_pipeline_builder.git',
        scm_branch: 'master',
        scm_params: {
          remote_name: 'origin',
          skip_tag: true
        },
        wrappers: [{ ansicolor: true }],
        builders: [{ shell_command: "echo 'Running DummyPipeline'" }]
      }
      result = compiler.compile(job, settings_bag)
      expect(result[1]).to eq(job_compiled)
    end

    it 'compiles a job with a downstream name change' do
      job = {
        name: '{{name}}-00',
        description: '{{description}}',
        scm_provider: 'git',
        scm_url: '{{pipeline_repo}}',
        scm_branch: '{{pipeline_branch}}',
        scm_params: {
          remote_name: 'origin',
          skip_tag: true
        },
        wrappers: [{ ansicolor: true }],
        builders: [{ shell_command: "echo 'Running {{name}}'\necho 'About to run {{job@{{name}}-01}}'\n" }],
        publishers: [{ downstream: { project: '{{job@{{name}}-01}}' } }]
      }
      job_compiled = {
        name: 'DummyPipeline-00',
        description: 'Do not edit this job through the web!',
        scm_provider: 'git',
        scm_url: 'git@github.com:constantcontact/jenkins_pipeline_builder.git',
        scm_branch: 'master',
        scm_params: {
          remote_name: 'origin',
          skip_tag: true
        },
        wrappers: [{ ansicolor: true }],
        builders: [{ shell_command: "echo 'Running DummyPipeline'\necho 'About to run DummyPipeline-02'\n" }],
        publishers: [{ downstream: { project: 'DummyPipeline-02' } }]
      }
      result = compiler.compile(job, settings_bag)
      expect(result[1]).to eq(job_compiled)
    end

    it 'compiles an enabled job with a string parameter' do
      my_job = { name: '{{name}}-00',
                 triggers: [{ periodic_build: { enabled: true, parameters: '{{var}}' } }] }
      compiled_job = { name: 'name-00',
                       triggers: [{ periodic_build: 'this_is_a_var' }] }
      settings_bag = { var: 'this_is_a_var', name: 'name' }

      result = compiler.compile(my_job, settings_bag)
      expect(result[1]).to eq(compiled_job)
    end
  end

  describe '#enable_blocks' do
    it 'generates correct new jobs with true' do
      item = { enabled: '{{use1}}', parameters: { rootPom: 'path_to_pomasd' } }
      settings = { name: 'PushTest', description: 'DB Pipeline tooling', git_repo: 'git@github.roving.com:devops/DBPipeline.git', git_branch: 'master', excluded_user: 'buildmaster', hipchat_room: 'CD Builds', hipchat_auth_token: 'f3e98ed54605b36f56dd2c562e3775', discard_days: '30', discard_number: '100', maven_name: 'tools-maven-3.0.3', hipchat_jenkins_url: 'https://cd-jenkins.ad.prodcc.net/', use1: true }
      success, item = compiler.handle_enable(item, settings)
      expect(success).to be true
      expect(item).to eq(rootPom: 'path_to_pomasd')
    end

    it 'generates correct new jobs when the params are a string' do
      item = { enabled: '{{use1}}', parameters: 'path_to_pomasd' }
      settings = { name: 'PushTest', description: 'DB Pipeline tooling', git_repo: 'git@github.roving.com:devops/DBPipeline.git', git_branch: 'master', excluded_user: 'buildmaster', hipchat_room: 'CD Builds', hipchat_auth_token: 'f3e98ed54605b36f56dd2c562e3775', discard_days: '30', discard_number: '100', maven_name: 'tools-maven-3.0.3', hipchat_jenkins_url: 'https://cd-jenkins.ad.prodcc.net/', use1: true }
      success, item = compiler.handle_enable(item, settings)
      expect(success).to be true
      expect(item).to eq('path_to_pomasd')
    end

    it 'generates correct new jobs with false' do
      item = { enabled: '{{use1}}', parameters: { rootPom: 'path_to_pomasd' } }
      settings = { name: 'PushTest', description: 'DB Pipeline tooling', git_repo: 'git@github.roving.com:devops/DBPipeline.git', git_branch: 'master', excluded_user: 'buildmaster', hipchat_room: 'CD Builds', hipchat_auth_token: 'f3e98ed54605b36f56dd2c562e3775', discard_days: '30', discard_number: '100', maven_name: 'tools-maven-3.0.3', hipchat_jenkins_url: 'https://cd-jenkins.ad.prodcc.net/', use1: false }
      success, item = compiler.handle_enable(item, settings)
      expect(success).to be true
      expect(item).to eq({})
    end

    it 'fails when value not found' do
      item = { enabled: '{{use_fail}}', parameters: { rootPom: 'path_to_pomasd' } }
      settings = { name: 'PushTest', description: 'DB Pipeline tooling', git_repo: 'git@github.roving.com:devops/DBPipeline.git', git_branch: 'master', excluded_user: 'buildmaster', hipchat_room: 'CD Builds', hipchat_auth_token: 'f3e98ed54605b36f56dd2c562e3775', discard_days: '30', discard_number: '100', maven_name: 'tools-maven-3.0.3', hipchat_jenkins_url: 'https://cd-jenkins.ad.prodcc.net/', use1: true }
      success, _ = compiler.handle_enable(item, settings)
      expect(success).to be false
    end

    it 'removes empty builders' do
      item = { enabled: '{{use}}', parameters: { rootPom: 'one' } }
      settings = { name: 'PushTest', description: 'DB Pipeline tooling', git_repo: 'git@github.roving.com:devops/DBPipeline.git', git_branch: 'master', excluded_user: 'buildmaster', hipchat_room: 'CD Builds', hipchat_auth_token: 'f3e98ed54605b36f56dd2c562e3775', discard_days: '30', discard_number: '100', maven_name: 'tools-maven-3.0.3', hipchat_jenkins_url: 'https://cd-jenkins.ad.prodcc.net/', use: false }
      success, result = compiler.handle_enable(item, settings)
      expect(success).to be true
      expect(result).to eq({})
    end
  end
end
