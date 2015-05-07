require File.expand_path('../spec_helper', __FILE__)
require 'webmock/rspec'

describe JenkinsPipelineBuilder::PullRequest do
  before :each do
    JenkinsPipelineBuilder.registry.registry[:job][:scm_params].installed_version = '1000.0'
  end
  after :each do
    JenkinsPipelineBuilder.registry.registry[:job][:scm_params].clear_installed_version
  end
  let(:project) do
    {
      name: 'pull_req_test',
      type: :project,
      value: {
        name: 'pull_req_test',
        jobs: ['{{name}}-00', '{{name}}-10', '{{name}}-11']
      }
    }
  end
  let(:value) { { jobs: ['{{name}}-10', '{{name}}-11'] } }
  let(:pull_request) do
    {
      name: '{{name}}-00',
      type: :job,
      name: '{{name}}-00',
      job_type: 'pull_request_generator',
      git_url: 'https://www.github.com/',
      git_repo: 'jenkins_pipeline_builder',
      git_org: 'constantcontact',
      value: value,
      builders: [
        { shell_command: 'echo "shell command"' }
      ]
    }
  end
  let(:job1) { '{{name}}-10' }
  let(:job2) { '{{name}}-11' }
  let(:jobs) do
    {
      job1 => {
        name: job1,
        type: :'job-template',
        value: {
          name: job1,
          description: '{{description}}',
          publishers: [{ downstream: { project: "{{job@#{job2}}}" } }]
        }
      },
      job2 => {
        name: job2,
        type: :'job-template',
        value: {
          name: job2,
          description: '{{description}}'
        }
      }
    }
  end
  let(:post_scm_params) do
    {
      changelog_to_branch: {
        remote: 'origin',
        branch: 'pr/{{pull_request_number}}/head'
      },
      refspec: 'refs/pull/{{pull_request_number}}/head:refs/remotes/origin/pr/{{pull_request_number}}/head'
    }
  end
  let(:post_jobs) do
    {
      '{{name}}-10' => {
        name: '{{name}}-10',
        type: :'job-template',
        value: {
          name: '{{name}}-10',
          description: '{{description}}',
          publishers: [{ downstream: { project: '{{job@{{name}}-11}}' } }],
          scm_branch: 'origin/pr/{{pull_request_number}}/head',
          scm_params: post_scm_params
        }
      },
      '{{name}}-11' => {
        name: '{{name}}-11',
        type: :'job-template',
        value: {
          name: '{{name}}-11',
          description: '{{description}}',
          scm_branch: 'origin/pr/{{pull_request_number}}/head',
          scm_params: post_scm_params
        }
      }
    }
  end
  describe '#initialize' do
    it 'process pull_request' do
      pull = described_class.new(project, 2, jobs, pull_request)
      post_project = {
        name: 'pull_req_test-PR2',
        type: :project,
        value: {
          name: 'pull_req_test-PR2',
          jobs: ['{{name}}-00', '{{name}}-10', '{{name}}-11'],
          pull_request_number: '2'
        }
      }

      expect(pull.project).to eq(post_project)
      expect(pull.jobs).to eq(post_jobs)
    end
  end

  describe '#git_version_0' do
    let(:post_scm_params) do
      { refspec: 'refs/pull/{{pull_request_number}}/head:refs/remotes/origin/pr/{{pull_request_number}}/head' }
    end

    before :each do
      JenkinsPipelineBuilder.registry.registry[:job][:scm_params].installed_version = '0'
    end
    it 'process pull_request' do
      pull = described_class.new(project, 2, jobs, pull_request)
      expect(pull.jobs).to eq(post_jobs)
    end
  end

  describe '#git_version_2' do
    before :each do
      JenkinsPipelineBuilder.registry.registry[:job][:scm_params].installed_version = '2.0'
    end
    it 'process pull_request' do
      pull = described_class.new(project, 2, jobs, pull_request)
      expect(pull.jobs).to eq(post_jobs)
    end
  end

  context 'when the job does not have {{name}} in it' do
    let(:project) do
      {
        name: 'pull_req_test',
        type: :project,
        app_name: 'my_app',
        value: {
          name: 'pull_req_test',
          app_name: 'my_app',
          jobs: ['{{app_name}}-00', '{{app_name}}-10', '{{app_name}}-11']
        }
      }
    end
    let(:value) do
      {
        inject_pr_into: :app_name,
        jobs: ['{{app_name}}-10', '{{app_name}}-11']
      }
    end
    let(:job1) { '{{app_name}}-10' }
    let(:job2) { '{{app_name}}-11' }
    it 'injects the pr number into the job name when told to' do
      pull = described_class.new project, 2, jobs, pull_request
      expect(pull.project[:value][:app_name]).to eq '{{app_name}}-PR2'
    end
  end
end
