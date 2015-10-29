require File.expand_path('../spec_helper', __FILE__)
require 'json'

describe JenkinsPipelineBuilder::PullRequestGenerator do
  let(:application_name) { 'testapp' }
  let(:git_url) { 'https://github.com' }
  let(:git_org) { 'git_org' }
  let(:git_repo) { 'git_repo' }
  let(:prs) { (1..10).map { |n| "#{application_name}-PR#{n}" } }
  let(:closed_prs) { (1..6).map { |n| "#{application_name}-PR#{n}" } }
  let(:open_prs_json) { (7..10).map { |n| { number: n } }.to_json }
  let(:url) { "#{git_url}/api/v3/repos/#{git_org}/#{git_repo}/pulls" }
  let(:job_collection) do
    double('job_collection',
           defaults: { value: { application_name: application_name } },
           jobs: [{ value: { scm_branch: 'master' } }])
  end
  subject do
    JenkinsPipelineBuilder::PullRequestGenerator.new(
      application_name: application_name,
      git_url: git_url,
      git_org: git_org,
      git_repo: git_repo)
  end

  context '#delete_closed_prs' do
    it 'deletes closed prs' do
      stub_request(:get, "#{git_url}/api/v3/repos/#{git_org}/#{git_repo}/pulls")
        .with(headers: { 'Accept' => '*/*',
                         'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                         'Host' => 'github.com',
                         'User-Agent' => 'Ruby' })
        .to_return(status: 200, body: open_prs_json, headers: {})
      job = double('job')
      expect(job).to receive(:list).with("#{application_name}-PR.*").and_return prs
      client = double('client', job: job)
      allow(JenkinsPipelineBuilder).to receive(:client).and_return client
      closed_prs.each { |pr| expect(job).to receive(:delete).with(pr) }
      subject.delete_closed_prs
    end
  end

  context '#convert!' do
    it 'converts the job application name' do
      stub_request(:get, "#{git_url}/api/v3/repos/#{git_org}/#{git_repo}/pulls")
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
      stub_request(:get, "#{git_url}/api/v3/repos/#{git_org}/#{git_repo}/pulls")
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
          changelog_to_branch: { remote: 'origin', branch: "pr/#{pr}/head" }
        }
      )
    end
  end
end
