require File.expand_path('../spec_helper', __FILE__)

describe JenkinsPipelineBuilder::PullRequestGenerator do
  describe '#initialize' do
    it 'can work without a csv'
    it 'can work with a csv'
  end
end

describe JenkinsPipelineBuilder::PullRequest do
  describe '#initialize' do
    it 'duplicates the vars'
    it 'changes the git defaults'
    it 'changes the name of the project'
    it 'pushes any template changes'
  end
end
