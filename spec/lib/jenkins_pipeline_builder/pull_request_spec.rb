require File.expand_path('../spec_helper', __FILE__)
require 'webmock/rspec'

describe JenkinsPipelineBuilder::PullRequest do
  before :each do
    JenkinsPipelineBuilder.registry.registry[:job][:scm_params].installed_version = '1000.0'
  end
  after :each do
    JenkinsPipelineBuilder.registry.registry[:job][:scm_params].clear_installed_version
  end
  let(:pull_request_class) { JenkinsPipelineBuilder::PullRequest }
  let(:project) { { name: 'pull_req_test', type: :project, value: { name: 'pull_req_test', jobs: ['{{name}}-00', '{{name}}-10', '{{name}}-11'] } } }
  let(:pull_request) { { name: '{{name}}-00', type: :job, name: '{{name}}-00', job_type: 'pull_request_generator', git_url: 'https://www.github.com/', git_repo: 'jenkins_pipeline_builder', git_org: 'constantcontact', value: { jobs: ['{{name}}-10', '{{name}}-11'] }, builders: [{ shell_command: 'generate -v || gem install jenkins_pipeline_builder\ngenerate pipeline -c config/{{login_config}} pull_request pipeline/ {{name}}\n' }] } }
  let(:jobs) { { '{{name}}-10' => { name: '{{name}}-10', type: :'job-template', value: { name: '{{name}}-10', description: '{{description}}', publishers: [{ downstream: { project: '{{job@{{name}}-11}}' } }] }  }, '{{name}}-11' => { name: '{{name}}-11', type: :'job-template', value: { name: '{{name}}-11', description: '{{description}}' } } } }
  describe '#initialize' do
    it 'process pull_request' do
      pull = pull_request_class.new(project, 2, jobs, pull_request)
      post_jobs = { '{{name}}-10' => { name: '{{name}}-10', type: :'job-template', value: { name: '{{name}}-10', description: '{{description}}', publishers: [{ downstream: { project: '{{job@{{name}}-11}}' } }], scm_branch: 'origin/pr/{{pull_request_number}}/head', scm_params: { changelog_to_branch: { remote: 'origin', branch: 'pr/{{pull_request_number}}/head' }, refspec: 'refs/pull/{{pull_request_number}}/head:refs/remotes/origin/pr/{{pull_request_number}}/head' } } }, '{{name}}-11' => { name: '{{name}}-11', type: :'job-template', value: { name: '{{name}}-11', description: '{{description}}', scm_branch: 'origin/pr/{{pull_request_number}}/head', scm_params: { changelog_to_branch: { remote: 'origin', branch: 'pr/{{pull_request_number}}/head' },  refspec: 'refs/pull/{{pull_request_number}}/head:refs/remotes/origin/pr/{{pull_request_number}}/head' } } } }
      post_project = { name: 'pull_req_test-PR2', type: :project, value: { name: 'pull_req_test-PR2', jobs: ['{{name}}-00', '{{name}}-10', '{{name}}-11'], pull_request_number: '2' } }

      expect(pull.project).to eq(post_project)
      expect(pull.jobs).to eq(post_jobs)
    end
  end

  describe '#git_version_0' do
    before :each do
      JenkinsPipelineBuilder.registry.registry[:job][:scm_params].installed_version = '0'
    end
    it 'process pull_request' do
      pull = pull_request_class.new(project, 2, jobs, pull_request)
      post_jobs = { '{{name}}-10' => { name: '{{name}}-10', type: :'job-template', value: { name: '{{name}}-10', description: '{{description}}', publishers: [{ downstream: { project: '{{job@{{name}}-11}}' } }], scm_branch: 'origin/pr/{{pull_request_number}}/head', scm_params: { refspec: 'refs/pull/{{pull_request_number}}/head:refs/remotes/origin/pr/{{pull_request_number}}/head' } } }, '{{name}}-11' => { name: '{{name}}-11', type: :'job-template', value: { name: '{{name}}-11', description: '{{description}}', scm_branch: 'origin/pr/{{pull_request_number}}/head', scm_params: { refspec: 'refs/pull/{{pull_request_number}}/head:refs/remotes/origin/pr/{{pull_request_number}}/head' } } } }
      expect(pull.jobs).to eq(post_jobs)
    end
  end

  describe '#git_version_2' do
    before :each do
      JenkinsPipelineBuilder.registry.registry[:job][:scm_params].installed_version = '2.0'
    end
    it 'process pull_request' do
      pull = pull_request_class.new(project, 2, jobs, pull_request)
      post_jobs = { '{{name}}-10' => { name: '{{name}}-10', type: :'job-template', value: { name: '{{name}}-10', description: '{{description}}', publishers: [{ downstream: { project: '{{job@{{name}}-11}}' } }], scm_branch: 'origin/pr/{{pull_request_number}}/head', scm_params: { refspec: 'refs/pull/{{pull_request_number}}/head:refs/remotes/origin/pr/{{pull_request_number}}/head', changelog_to_branch: { remote: 'origin', branch: 'pr/{{pull_request_number}}/head' } } } }, '{{name}}-11' => { name: '{{name}}-11', type: :'job-template', value: { name: '{{name}}-11', description: '{{description}}', scm_branch: 'origin/pr/{{pull_request_number}}/head', scm_params: { refspec: 'refs/pull/{{pull_request_number}}/head:refs/remotes/origin/pr/{{pull_request_number}}/head', changelog_to_branch: { remote: 'origin', branch: 'pr/{{pull_request_number}}/head' } } } } }
      expect(pull.jobs).to eq(post_jobs)
    end
  end
end
