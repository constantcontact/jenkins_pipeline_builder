require File.expand_path('spec_helper', __dir__)
require 'json'

describe JenkinsPipelineBuilder::PullRequestGenerator do
  let(:application_name) { 'testapp' }
  let(:github_site) { 'https://github.com' }
  let(:git_org) { 'git_org' }
  let(:git_repo_name) { 'git_repo' }
  let(:prs) { (1..10).map { |n| "#{application_name}-PR#{n}" } }
  let(:closed_prs) { (1..6).map { |n| "#{application_name}-PR#{n}" } }
  let(:open_prs_json) { (7..10).map { |n| { number: n, base: { ref: 'master' } } }.to_json }
  let(:url) { "#{github_site}/api/v3/repos/#{git_org}/#{git_repo_name}/pulls" }
  let(:params) do
    {
      github_site: github_site,
      git_org: git_org,
      git_repo_name: git_repo_name,
      application_name: application_name
    }
  end
  let(:job_collection) do
    double('job_collection',
           defaults: { value: { application_name: application_name } },
           jobs: [{ value: { scm_branch: 'master', scm_params: { random: 'foo' } } }])
  end
  subject { JenkinsPipelineBuilder::PullRequestGenerator.new params }

  context '#initialize' do
    it 'fails when one of the params is not set' do
      expect do
        JenkinsPipelineBuilder::PullRequestGenerator.new(application_name: 'name')
      end.to raise_error('Please set github_site, git_org and git_repo_name in your project.')
    end
    it 'fails when application_name is not set' do
      expect do
        JenkinsPipelineBuilder::PullRequestGenerator.new(github_site: 'foo', git_org: 'bar', git_repo_name: 'baz')
      end.to raise_error('Please set "application_name" in your project!')
    end
    it 'fails when github is not reponding properly' do
      stub_request(:get, url)
        .with(headers: { 'Accept' => '*/*',
                         'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                         'Host' => 'github.com',
                         'User-Agent' => 'Ruby' })
        .to_raise 'error'
      expect { subject }.to raise_error('Failed connecting to github!')
    end
  end

  context '#delete_closed_prs' do
    it 'deletes closed prs' do
      stub_request(:get, url)
        .with(headers: { 'Accept' => '*/*',
                         'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                         'Host' => 'github.com',
                         'User-Agent' => 'Ruby' })
        .to_return(status: 200, body: open_prs_json, headers: {})
      job = double('job')
      expect(job).to receive(:list).with("^#{application_name}-PR(\\d+)-(.*)$").and_return prs
      client = double('client', job: job)
      expect(JenkinsPipelineBuilder).to receive(:debug).and_return false
      allow(JenkinsPipelineBuilder).to receive(:client).and_return client
      closed_prs.each { |pr| expect(job).to receive(:delete).with(pr) }
      subject.delete_closed_prs
    end

    it 'does not fail when there are no closed prs' do
      stub_request(:get, url)
        .with(headers: { 'Accept' => '*/*',
                         'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                         'Host' => 'github.com',
                         'User-Agent' => 'Ruby' })
        .to_return(status: 200, body: open_prs_json, headers: {})
      job = double('job')
      expect(job).to receive(:list).with("^#{application_name}-PR(\\d+)-(.*)$").and_return prs - closed_prs
      client = double('client', job: job)
      expect(JenkinsPipelineBuilder).to receive(:debug).and_return false
      allow(JenkinsPipelineBuilder).to receive(:client).and_return client
      expect(job).not_to receive(:delete)
      subject.delete_closed_prs
    end
  end

  context '#convert!' do
    before(:each) do
      stub_request(:get, url)
        .with(headers: { 'Accept' => '*/*',
                         'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                         'Host' => 'github.com',
                         'User-Agent' => 'Ruby' })
        .to_return(status: 200, body: open_prs_json, headers: {})
    end

    let(:pr_number) { 8 }

    it 'converts the job application name' do
      collection = job_collection.clone
      subject.convert! collection, pr_number
      expect(collection.defaults[:value][:application_name]).to eq "#{application_name}-PR#{pr_number}"
    end

    it 'provides the PR number to the job settings' do
      collection = job_collection.clone
      subject.convert! collection, pr_number
      expect(collection.defaults[:value][:pull_request_number]).to eq pr_number.to_s
    end

    it 'overrides the git params' do
      collection = job_collection.clone
      subject.convert! collection, pr_number
      expect(collection.jobs.first[:value]).to eq(
        scm_branch: "origin/pr/#{pr_number}/head",
        scm_params: {
          refspec: "refs/pull/#{pr_number}/head:refs/remotes/origin/pr/#{pr_number}/head",
          changelog_to_branch: { remote: 'origin', branch: "pr/#{pr_number}/head" },
          random: 'foo'
        }
      )
    end

    it 'does not override extra params' do
      collection = job_collection.clone
      subject.convert! collection, pr_number
      expect(collection.jobs.first[:value]).to eq(
        scm_branch: "origin/pr/#{pr_number}/head",
        scm_params: {
          refspec: "refs/pull/#{pr_number}/head:refs/remotes/origin/pr/#{pr_number}/head",
          changelog_to_branch: { remote: 'origin', branch: "pr/#{pr_number}/head" },
          random: 'foo'
        }
      )
    end
  end
end
