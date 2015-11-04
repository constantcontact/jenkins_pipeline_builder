require File.expand_path('../spec_helper', __FILE__)
require 'json'

describe JenkinsPipelineBuilder::PullRequestGenerator do
  let(:application_name) { 'testapp' }
  let(:github_site) { 'https://github.com' }
  let(:git_org) { 'git_org' }
  let(:git_repo_name) { 'git_repo' }
  let(:prs) { (1..10).map { |n| "#{application_name}-PR#{n}" } }
  let(:closed_prs) { (1..6).map { |n| "#{application_name}-PR#{n}" } }
  let(:open_prs_json) { (7..10).map { |n| { number: n } }.to_json }
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

  context '#delete_closed_prs' do
    it 'deletes closed prs' do
      stub_request(:get, url)
        .with(headers: { 'Accept' => '*/*',
                         'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                         'Host' => 'github.com',
                         'User-Agent' => 'Ruby' })
        .to_return(status: 200, body: open_prs_json, headers: {})
      job = double('job')
      expect(job).to receive(:list).with("#{application_name}-PR.*").and_return prs
      client = double('client', job: job)
      expect(JenkinsPipelineBuilder).to receive(:debug).and_return false
      allow(JenkinsPipelineBuilder).to receive(:client).and_return client
      closed_prs.each { |pr| expect(job).to receive(:delete).with(pr) }
      subject.delete_closed_prs
    end
  end

  context '#convert!' do
    it 'converts the job application name' do
      stub_request(:get, url)
        .with(headers: { 'Accept' => '*/*',
                         'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                         'Host' => 'github.com',
                         'User-Agent' => 'Ruby' })
        .to_return(status: 200, body: open_prs_json, headers: {})
      collection = job_collection.clone
      subject.convert! collection, 8
      expect(collection.defaults[:value][:application_name]).to eq "#{application_name}-PR8"
    end

    it 'overrides the git params' do
      stub_request(:get, url)
        .with(headers: { 'Accept' => '*/*',
                         'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                         'Host' => 'github.com',
                         'User-Agent' => 'Ruby' })
        .to_return(status: 200, body: open_prs_json, headers: {})
      pr = 8
      collection = job_collection.clone
      subject.convert! collection, pr
      expect(collection.jobs.first[:value]).to eq(
        scm_branch: "origin/pr/#{pr}/head",
        scm_params: {
          refspec: "refs/pull/#{pr}/head:refs/remotes/origin/pr/#{pr}/head",
          changelog_to_branch: { remote: 'origin', branch: "pr/#{pr}/head" },
          random: 'foo'
        }
      )
    end

    it 'does not override extra params' do
      stub_request(:get, url)
        .with(headers: { 'Accept' => '*/*',
                         'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                         'Host' => 'github.com',
                         'User-Agent' => 'Ruby' })
        .to_return(status: 200, body: open_prs_json, headers: {})
      pr = 8
      collection = job_collection.clone
      subject.convert! collection, pr
      expect(collection.jobs.first[:value]).to eq(
        scm_branch: "origin/pr/#{pr}/head",
        scm_params: {
          refspec: "refs/pull/#{pr}/head:refs/remotes/origin/pr/#{pr}/head",
          changelog_to_branch: { remote: 'origin', branch: "pr/#{pr}/head" },
          random: 'foo'
        }
      )
    end
  end
end
