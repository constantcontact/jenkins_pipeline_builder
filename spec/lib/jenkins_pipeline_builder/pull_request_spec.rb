require 'rspec'
require File.expand_path('../../../../lib/jenkins_pipeline_builder', __FILE__)

describe JenkinsPipelineBuilder::PullRequestGenerator do
  describe '#initialize' do
    it 'create pull requests(stubbed)'
  end

  describe '#check_for_pull' do
    it 'get pull_request data from github'
  end

  describe '#purge_old' do
    it 'create a new csv'
    it 'update a csv'
  end
end

describe JenkinsPipelineBuilder::PullRequest do
  describe '#initialize' do
    it 'duplicates the vars'
    it 'calls run!'
  end

  describe '#run!' do
    it 'runs each function'
  end

  describe '#change_git!' do
    it 'changes the git details'
  end

  describe '#change_name!' do
    it 'changes the name of the project'
  end

  describe '#update_jobs!' do
    it 'pushes any template changes'
  end
end
