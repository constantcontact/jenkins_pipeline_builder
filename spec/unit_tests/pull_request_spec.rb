require 'unit_tests/spec_helper'

describe 'Test Creating a Pull Request' do
  before do
    @client = JenkinsApi::Client.new(
        server_ip: '127.0.0.1',
        server_port: 8080,
        username: 'username',
        password: 'password',
        log_location: '/dev/null'
    )
    # Request to get current pull requests from github
    stub_request(:any, 'https://www.github.com/api/v3/repos/constantcontact/jenkins_pipeline_builder/pulls').to_return(body: '[{"number": 5,"state": "open","title": "Update README again" },{"number": 6,"state": "open",  "title": "Update README again2"}]')
    stub_request(:any, 'http://username:password@127.0.0.1:8080/api/json').to_return(body: '{"assignedLabels":[{}],"mode":"NORMAL","nodeDescription":"the master Jenkins node","nodeName":"","numExecutors":2,"description":null,"jobs":[{"name":"PurgeTest-PR1","url":"http://localhost:8080/job/PurgeTest-PR1/","color":"notbuilt" },{"name":"PurgeTest-PR3","url":"http://localhost:8080/job/PurgeTest-PR3/","color":"notbuilt" },{"name":"PurgeTest-PR4","url":"http://localhost:8080/job/PurgeTest-PR4/","color":"notbuilt"}],"overallLoad":{},"primaryView":{"name":"All","url":"http://localhost:8080/" },"quietingDown":false,"slaveAgentPort":0,"unlabeledLoad":{},"useCrumbs":false,"useSecurity":true,"views":[{"name":"All","url":"http://localhost:8080/"}]}')
    # Requests to delete jobs 3 & 4
    stub_request(:any, 'http://username:password@127.0.0.1:8080/job/PurgeTest-PR3/doDelete').to_return(status: 200, body: '', headers: {})
    stub_request(:any, 'http://username:password@127.0.0.1:8080/job/PurgeTest-PR4/doDelete').to_return(status: 200, body: '', headers: {})
    @generator = JenkinsPipelineBuilder::Generator.new(@client)
    @generator.debug = false
    @generator.no_files = true
    @pull_req_gen = JenkinsPipelineBuilder::PullRequestGenerator.new(@generator)
  end

  ### Test methods:
  describe '#check_for_pull' do
    it 'get pull requests from github' do
      args = { git_url: 'https://www.github.com/', git_org: 'constantcontact', git_repo: 'jenkins_pipeline_builder' }
      result = @pull_req_gen.check_for_pull(args)
      expect(result).to eq([5, 6])
    end
  end

  describe '#purge_old' do
    before do
      @project = { name: 'PurgeTest' }
      @pull_requests = [1, 2, 3, 4]
    end
    after(:all) do
      FileUtils.rm_r 'pull_requests.csv'
    end
    it 'create a new csv' do
      @pull_req_gen.purge_old(@pull_requests, @project)
      contents = File.open('pull_requests.csv', 'rb') { |f| f.read }
      expect(contents).to eq('PurgeTest-PR1,PurgeTest-PR2,PurgeTest-PR3,PurgeTest-PR4')
    end
    it 'update the csv' do
      @pull_req_gen.purge_old([1, 2], @project)
      contents = File.open('pull_requests.csv', 'rb') { |f| f.read }
      expect(contents).to eq('PurgeTest-PR1,PurgeTest-PR2')
    end
  end
  describe 'PullRequest class' do
    it 'update the jobs/project to match the pull request' do
      project = { name: 'DummyPipeline', type: :project, value: { name: 'DummyPipeline', login_config: 'login.yml', jobs: ['{{name}}-00-Generate', '{{name}}-01-PullRequestGenerator', '{{name}}-10', '{{name}}-15-Provision', '{{name}}-16-HealthCheck'] } }
      number = 2
      main_collection = { '{{name}}-15-Provision' => { name: '{{name}}-15-Provision', type: :'job-template', value: { name: '{{name}}-15-Provision', description: '{{description}}', scm_provider: 'git', scm_url: '{{pipeline_repo}}', scm_branch: 'origin/pr/5/head', scm_params: { remote_name: 'origin', skip_tag: true, refspec: 'refs/pull/*:refs/remotes/origin/pr/*' }, discard_old: { days: '{{discard_days}}' }, hipchat: { room: '', 'start-notify' => false }, wrappers: [{ timestamp: true }, { ansicolor: true }], publishers: [{ downstream: { project: '{{job@{{name}}-16-HealthCheck}}' } }], builders: [{ shell_command: 'echo \'Running {{name}}-15-Provision\'' }] }  }, '{{name}}-16-HealthCheck' => { name: '{{name}}-16-HealthCheck', type: :job, value: { name: '{{name}}-16-HealthCheck', description: '{{description}}', builders: [{ shell_command: 'echo \'Running {{name}}-16-HealthCheck...\'' }], scm_branch: 'origin/pr/5/head', scm_params: { refspec: 'refs/pull/*:refs/remotes/origin/pr/*' } } }, '{{name}}-17-Cleanup' => { name: '{{name}}-17-Cleanup', type: :job, value: { name: '{{name}}-17-Cleanup', description: '{{description}}', builders: [{ shell_command: 'echo \'Running {{name}}-17-Cleanup...\'' }], scm_branch: 'origin/pr/5/head', scm_params: { refspec: 'refs/pull/*:refs/remotes/origin/pr/*' } } } }
      generator_job = { name: '{{name}}-01-PullRequestGenerator', type: :job, value: { name: '{{name}}-01-PullRequestGenerator', job_type: 'pull_request_generator', git_url: 'https://www.github.com/', git_repo: 'jenkins_pipeline_builder', git_org: 'constantcontact', jobs: [{ '{{name}}-15-Provision' => {}, result: { name: 'DummyPipeline-PR5-15-Provision', description: 'Do not edit this job through the web!', scm_provider: 'git', scm_url: 'git@github.roving.com:constantcontact/jenkins_pipeline_builder.git', scm_branch: 'origin/pr/5/head', scm_params: { remote_name: 'origin', skip_tag: true, refspec: 'refs/pull/*:refs/remotes/origin/pr/*' }, discard_old: { days: '14' }, hipchat: { room: '', 'start-notify' => false }, wrappers: [{ timestamp: true }, { ansicolor: true }], publishers: [{ downstream: { project: 'DummyPipeline-PR5-16-HealthCheck', data: [{ params: '' }] } }], builders: [{ shell_command: 'echo \'Running DummyPipeline-PR5-15-Provision\'' }], job_type: 'free_style', keep_dependencies: false, block_build_when_downstream_building: false, block_build_when_upstream_building: false, concurrent_build: false, scm_use_head_if_tag_not_found: false } }, { '{{name}}-16-HealthCheck' => {}, result: { name: 'DummyPipeline-PR5-16-HealthCheck', description: 'Do not edit this job through the web!', builders: [{ shell_command: 'echo \'Running DummyPipeline-PR5-16-HealthCheck...\'' }], scm_branch: 'origin/pr/5/head', scm_params: { refspec: 'refs/pull/*:refs/remotes/origin/pr/*' }, job_type: 'free_style', keep_dependencies: false, block_build_when_downstream_building: false, block_build_when_upstream_building: false, concurrent_build: false } }, { '{{name}}-17-Cleanup' => {}, result: { name: 'DummyPipeline-PR5-17-Cleanup', description: 'Do not edit this job through the web!', builders: [{ shell_command: 'echo \'Running DummyPipeline-PR5-17-Cleanup...\'' }], scm_branch: 'origin/pr/5/head', scm_params: { refspec: 'refs/pull/*:refs/remotes/origin/pr/*' }, job_type: 'free_style', keep_dependencies: false, block_build_when_downstream_building: false, block_build_when_upstream_building: false, concurrent_build: false } }], builders: [{ shell_command: 'generate -v || gem install jenkins_pipeline_builder\ngenerate pipeline -c config/{{login_config}} pull_request pipeline/ {{name}}\n' }] } }
      @pull_request = JenkinsPipelineBuilder::PullRequest.new(project, number, main_collection, generator_job)
      post_jobs = { '{{name}}-15-Provision' => { name: '{{name}}-15-Provision', type: :'job-template', value: { name: '{{name}}-15-Provision', description: '{{description}}', scm_provider: 'git', scm_url: '{{pipeline_repo}}', scm_branch: 'origin/pr/2/head', scm_params: { remote_name: 'origin', skip_tag: true, refspec: 'refs/pull/*:refs/remotes/origin/pr/*' }, discard_old: { days: '{{discard_days}}' }, hipchat: { room: '', 'start-notify' => false }, wrappers: [{ timestamp: true }, { ansicolor: true }], publishers: [{ downstream: { project: '{{job@{{name}}-16-HealthCheck}}' } }], builders: [{ shell_command: 'echo \'Running {{name}}-15-Provision\'' }] }  }, '{{name}}-16-HealthCheck' => { name: '{{name}}-16-HealthCheck', type: :job, value: { name: '{{name}}-16-HealthCheck', description: '{{description}}', builders: [{ shell_command: 'echo \'Running {{name}}-16-HealthCheck...\'' }], scm_branch: 'origin/pr/2/head', scm_params: { refspec: 'refs/pull/*:refs/remotes/origin/pr/*' } } }, '{{name}}-17-Cleanup' => { name: '{{name}}-17-Cleanup', type: :job, value: { name: '{{name}}-17-Cleanup', description: '{{description}}', builders: [{ shell_command: 'echo \'Running {{name}}-17-Cleanup...\'' }], scm_branch: 'origin/pr/2/head', scm_params: { refspec: 'refs/pull/*:refs/remotes/origin/pr/*' } } } }
      post_project = { name: 'DummyPipeline-PR2', type: :project, value: { name: 'DummyPipeline-PR2', login_config: 'login.yml', jobs: ['{{name}}-00-Generate', '{{name}}-01-PullRequestGenerator', '{{name}}-10', '{{name}}-15-Provision', '{{name}}-16-HealthCheck'] } }

      expect(@pull_request.project).to eq(post_project)
      expect(@pull_request.jobs).to eq(post_jobs)
    end
  end

  ### Test whole thing (run command)
  describe '#run' do
    after do
      FileUtils.rm_r 'pull_requests.csv'
    end
    it 'running whole program' do
      expect(@generator).to receive(:create_or_update).exactly(4).times do |job, _xml|
        expect(%w(pull_req_test-PR5-10 pull_req_test-PR5-11 pull_req_test-PR6-10 pull_req_test-PR6-11)).to include(job[:name])
      end
      @generator.load_collection_from_path(File.expand_path('../fixtures/pull_request/', __FILE__))
      project = { name: 'pull_req_test', type: :project, value: { name: 'pull_req_test', jobs: ['{{name}}-00', '{{name}}-10', '{{name}}-11'] } }
      job_collection = { '{{name}}-10' => { name: '{{name}}-10', type: :'job-template', value: { name: '{{name}}-10', description: '{{description}}', publishers: [{ downstream: { project: '{{job@{{name}}-11}}' } }] }  }, '{{name}}-11' => { name: '{{name}}-11', type: :'job-template', value: { name: '{{name}}-11', description: '{{description}}' } } }
      generator_job = { name: '{{name}}-00', type: :job, value: { name: '{{name}}-00', job_type: 'pull_request_generator', git_url: 'https://www.github.com/', git_repo: 'jenkins_pipeline_builder', git_org: 'constantcontact', jobs: ['{{name}}-10', '{{name}}-11'], builders: [{ shell_command: 'generate -v || gem install jenkins_pipeline_builder\ngenerate pipeline -c config/{{login_config}} pull_request pipeline/ {{name}}\n' }] } }
      @pull_req_gen.run(project, job_collection, generator_job)
    end
  end
end
