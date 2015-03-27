require File.expand_path('../spec_helper', __FILE__)

describe JenkinsPipelineBuilder::View do
  before(:all) do
    JenkinsPipelineBuilder.credentials = {
      server_ip: '127.0.0.1',
      server_port: 8080,
      username: 'username',
      password: 'password',
      log_location: '/dev/null'
    }
    generator = JenkinsPipelineBuilder.generator
    @view = JenkinsPipelineBuilder::View.new(generator)
  end
  let(:path) { File.expand_path('../fixtures/view_test/', __FILE__) }
  let(:view) { { name: 'view', parent_view: 'ParentView', type: 'categorizedView', description: 'ViewTest', regex: 'ViewTest.*', groupingRules: [{ groupRegex: 'ViewTest-1.*', namingRule: '1. Commit Stage' }] } }

  describe '#generate' do
    it 'calls create with the correct parameters' do
      expect(@view).to receive(:create).with(view).exactly(1).times
      @view.generate("#{path}/parent_view.yaml")
    end
  end

  describe '#create' do
    before do
      stub_request(:any, 'http://username:password@127.0.0.1:8080/api/json').to_return(body: '{"assignedLabels":[{}],"mode":"NORMAL","nodeDescription":"the master Jenkins node","nodeName":"","numExecutors":2,"description":null,"jobs":[{"name":"PurgeTest-PR1","url":"http://localhost:8080/job/PurgeTest-PR1/","color":"notbuilt" },{"name":"PurgeTest-PR3","url":"http://localhost:8080/job/PurgeTest-PR3/","color":"notbuilt" },{"name":"PurgeTest-PR4","url":"http://localhost:8080/job/PurgeTest-PR4/","color":"notbuilt"}],"overallLoad":{},"primaryView":{"name":"All","url":"http://localhost:8080/" },"quietingDown":false,"slaveAgentPort":0,"unlabeledLoad":{},"useCrumbs":false,"useSecurity":true,"views":[{"name":"All","url":"http://localhost:8080/"}, {"name":"duplicate_view"}]}')
      stub_request(:any, 'http://username:password@127.0.0.1:8080/view/ParentView/api/json').to_return(body: '{"assignedLabels":[{}],"mode":"NORMAL","nodeDescription":"the master Jenkins node","nodeName":"","numExecutors":2,"description":null,"jobs":[{"name":"PurgeTest-PR1","url":"http://localhost:8080/job/PurgeTest-PR1/","color":"notbuilt" },{"name":"PurgeTest-PR3","url":"http://localhost:8080/job/PurgeTest-PR3/","color":"notbuilt" },{"name":"PurgeTest-PR4","url":"http://localhost:8080/job/PurgeTest-PR4/","color":"notbuilt"}],"overallLoad":{},"primaryView":{"name":"All","url":"http://localhost:8080/" },"quietingDown":false,"slaveAgentPort":0,"unlabeledLoad":{},"useCrumbs":false,"useSecurity":true,"views":[{"name":"All","url":"http://localhost:8080/"}]}')
      stub_request(:post, /.*/).to_return(status: 200) # Stop actual creating/deleting
      allow(JenkinsPipelineBuilder).to receive(:debug).and_return false
    end
    context 'parent view is specified' do
      it 'needs to create the parent view and view' do
        expect(@view).to receive(:create_base_view).with('ParentView', 'nestedView').once
        expect(@view).to receive(:create_base_view).with('view', 'categorizedView', 'ParentView').once
        @view.generate("#{path}/parent_view.yaml")
      end
      it 'deletes a view if it already exists' do
        stub_request(:any, 'http://username:password@127.0.0.1:8080/view/ParentView/api/json').to_return(body: '{"assignedLabels":[{}],"mode":"NORMAL","nodeDescription":"the master Jenkins node","nodeName":"","numExecutors":2,"description":null,"jobs":[{"name":"PurgeTest-PR1","url":"http://localhost:8080/job/PurgeTest-PR1/","color":"notbuilt" },{"name":"PurgeTest-PR3","url":"http://localhost:8080/job/PurgeTest-PR3/","color":"notbuilt" },{"name":"PurgeTest-PR4","url":"http://localhost:8080/job/PurgeTest-PR4/","color":"notbuilt"}],"overallLoad":{},"primaryView":{"name":"All","url":"http://localhost:8080/" },"quietingDown":false,"slaveAgentPort":0,"unlabeledLoad":{},"useCrumbs":false,"useSecurity":true,"views":[{"name":"All","url":"http://localhost:8080/"}, {"name":"view"}]}')
        expect(@view).to receive(:delete).with('view', 'ParentView').once
        @view.generate("#{path}/parent_view.yaml")
      end
    end
    context 'no parent view' do
      it 'creates the view' do
        expect(@view).to receive(:create_base_view).with('RegularView', 'listview', nil).once
        @view.generate("#{path}/regular_view.yaml")
      end
      it 'deletes a view if overwriting' do
        expect(@view).to receive(:delete).with('duplicate_view').once
        @view.generate("#{path}/duplicate_view.yaml")
      end
    end
  end
end
