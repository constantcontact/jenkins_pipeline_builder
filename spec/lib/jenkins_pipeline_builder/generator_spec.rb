require File.expand_path('../spec_helper', __FILE__)

describe JenkinsPipelineBuilder::Generator do
  before :all do
    JenkinsPipelineBuilder.credentials = {
      server_ip: '127.0.0.1',
      server_port: 8080,
      username: 'username',
      password: 'password',
      log_location: '/dev/null'
    }
  end

  after :each do
    JenkinsPipelineBuilder.registry.clear_versions
  end

  before :each do
    @generator = JenkinsPipelineBuilder.generator
  end

  after(:each) do
    @generator.job_collection = JenkinsPipelineBuilder::JobCollection.new
  end

  describe 'initialized in before(:example)' do
    it 'creates a new generator' do
      expect(@generator.job_collection.collection).to be_empty
      expect(@generator.module_registry).not_to be_nil
    end

    it 'accepts new jobs into the job_collection' do
      job_name = 'sample_job'
      job_type = 'project'
      job_value = {}
      @generator.job_collection.collection[job_name] = { name: job_name, type: job_type, value: job_value }
      expect(@generator.job_collection.collection).not_to be_empty
      expect(@generator.job_collection.collection[job_name]).not_to be_nil
    end
  end

  describe '#client' do
    it 'returns the singleton JenkinsPipelineBuilder.client object' do
      expect(@generator.client).to be(JenkinsPipelineBuilder.client)
    end
  end

  describe '#view' do
    it 'returns a new JenkinsPipelineBuilder::View object' do
      view = @generator.view
      expect(view).not_to be_nil
      # expect(view.generator).to be(@generator)
    end
  end

  describe '#bootstrap' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'description' => '20.0', 'git' => '20.0' })
    end

    def bootstrap(fixture_path, job_name)
      JenkinsPipelineBuilder.debug!
      errors = @generator.bootstrap(fixture_path, job_name)
      errors
    end

    def fixture_path(fixture)
      File.expand_path("../fixtures/generator_tests/#{fixture}", __FILE__)
    end

    it 'produces no errors while creating pipeline SamplePipeline with view' do
      errors = bootstrap(fixture_path('sample_pipeline'), 'SamplePipeline')
      expect(errors).to be_empty
    end

    it 'produces no errors while creating a single job' do
      errors = bootstrap(fixture_path('sample_pipeline/SamplePipeline-10-Commit.yaml'), 'SamplePipeline-10-Commit')
      expect(errors).to be_empty
    end

    it 'produces no errors while creating pipeline TemplatePipeline' do
      errors = bootstrap(fixture_path('template_pipeline'), 'TemplatePipeline')
      expect(errors).to be_empty
    end

    it 'loads extensions in remote dependencies' do
      errors = bootstrap(fixture_path('template_pipeline'), 'TemplatePipeline')
      expect(errors).to be_empty
      expect(@generator.module_registry.registry[:job][:wrappers].keys).to include :test_wrapper
      @generator.module_registry.registry[:job][:wrappers].delete(:test_wrapper)
    end

    it 'overrides the remote dependencies with local ones' do
      errors = bootstrap(fixture_path('local_override/remote_and_local'), 'TemplatePipeline')
      expect(errors).to be_empty
      expect(@generator.job_collection.collection['{{name}}-10'][:value][:description]).to eq('Overridden stuff')
    end

    it 'fails to override when there are duplicate local items' do
      expect { bootstrap(fixture_path('local_override/all_local'), 'TemplatePipeline') }.to raise_error(StandardError)
    end

    # Things to check for:
    # Fail - Finds duplicate job names (load_job_collection)
    # Extension fails to register?
    # resolve_project returns false
    # Accumulates errors in publish_project/job path
    it 'produces no errors while creating a job dsl'
  end

  describe '#pull_request' do
    before :each do
      allow(JenkinsPipelineBuilder).to receive(:debug).and_return true
      JenkinsPipelineBuilder.registry.registry[:job][:scm_params].installed_version = '1000.0'
    end
    after :each do
      JenkinsPipelineBuilder.registry.registry[:job][:scm_params].clear_installed_version
    end

    let(:path) { File.expand_path('../fixtures/generator_tests/pullrequest_pipeline', __FILE__) }
    it 'produces no errors while creating pipeline PullRequest' do
      job_name = 'PullRequest'
      allow_any_instance_of(JenkinsPipelineBuilder::PullRequestGenerator).to receive(:check_for_pull).and_return([1])
      allow_any_instance_of(JenkinsPipelineBuilder::PullRequestGenerator).to receive(:purge_jobs).and_return(true)
      success = @generator.pull_request(path, job_name)
      expect(success).to be_truthy
    end

    it 'correctly creates jobs when there are multiple pulls open' do
      job_name = 'PullRequest'
      allow_any_instance_of(JenkinsPipelineBuilder::PullRequestGenerator).to receive(:check_for_pull).and_return([1, 2])
      job1 = double name: 'job name'
      job2 = double name: 'job name'
      expect(JenkinsPipelineBuilder::Job).to receive(:new).once.with(
        name: 'PullRequest-PR1-10-SampleJob', scm_branch: 'origin/pr/1/head', scm_params: {
          refspec: 'refs/pull/1/head:refs/remotes/origin/pr/1/head',
          changelog_to_branch: { remote: 'origin', branch: 'pr/1/head' }
        }
      ).and_return job1
      expect(JenkinsPipelineBuilder::Job).to receive(:new).once.with(
        name: 'PullRequest-PR2-10-SampleJob', scm_branch: 'origin/pr/2/head', scm_params: {
          refspec: 'refs/pull/2/head:refs/remotes/origin/pr/2/head',
          changelog_to_branch: { remote: 'origin', branch: 'pr/2/head' }
        }
      ).and_return job2
      expect(job1).to receive(:create_or_update).and_return true
      expect(job2).to receive(:create_or_update).and_return true
      expect(@generator.pull_request(path, job_name)).to be_truthy
    end
    # Things to check for
    # Fail - no PR job type found
    # Encounters failure during build process
    # Fails to purge old PR jobs from Jenkins
  end

  describe '#load_from_path' do
    let(:project_hash) do
      [{ 'defaults' => { 'name' => 'global', 'description' => 'Tests, all the tests' } },
       { 'project' => { 'name' => 'TestProject', 'jobs' => ['{{name}}-part1'] } }]
    end
    let(:view_hash) do
      [{ 'view' =>
        { 'name' => '{{name}} View', 'type' => 'listview', 'description' => '{{description}}', 'regex' => '{{name}}.*' }
      }]
    end

    it 'loads a yaml collection from a path' do
      path = File.expand_path('../fixtures/generator_tests/test_yaml_files', __FILE__)
      @generator.job_collection.load_from_path path
    end
    it 'loads a json collection from a path' do
      path = File.expand_path('../fixtures/generator_tests/test_json_files', __FILE__)
      @generator.job_collection.load_from_path path
    end
    it 'loads both yaml and json files from a path' do
      path = File.expand_path('../fixtures/generator_tests/test_combo_files', __FILE__)
      @generator.job_collection.load_from_path path
    end
  end

  describe '#dump' do
    it "writes a job's config XML to a file" do
      allow(JenkinsPipelineBuilder).to receive(:debug).and_return true
      job_name = 'test_job'
      body = ''
      test_path = File.expand_path('../fixtures/generator_tests', __FILE__)
      File.open("#{test_path}/#{job_name}.xml", 'r') do |f|
        f.each_line do |line|
          body << line
        end
      end
      stub_request(:get, 'http://username:password@127.0.0.1:8080/job/test_job/config.xml')
        .to_return(status:  200, body:  "#{body}", headers:  {})
      @generator.dump(job_name)
      expect(File.exist?("#{job_name}.xml")).to be true
      File.delete("#{job_name}.xml")
    end
  end

  describe '#file_mode' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'description' => '20.0', 'git' => '20.0' })
    end
    it 'generates xml and saves to disk without sending jobs to the server' do
      job_name = 'TemplatePipeline'
      path = File.expand_path('../fixtures/generator_tests/template_pipeline', __FILE__)
      errors = @generator.file(path, job_name)
      expect(errors).to be_empty
      expect(File.exist?("out/xml/#{job_name}-10.xml")).to be true
      expect(File.exist?("out/xml/#{job_name}-11.xml")).to be true
    end
  end
end
