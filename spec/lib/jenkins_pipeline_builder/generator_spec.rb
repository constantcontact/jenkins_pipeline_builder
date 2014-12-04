require File.expand_path('../spec_helper', __FILE__)

describe JenkinsPipelineBuilder::Generator do
  after :each do
    JenkinsPipelineBuilder.registry.clear_versions
  end

  before(:all) do
    JenkinsPipelineBuilder.credentials = {
      server_ip: '127.0.0.1',
      server_port: 8080,
      username: 'username',
      password: 'password',
      log_location: '/dev/null'
    }
    @generator = JenkinsPipelineBuilder.generator
  end

  after(:each) do
    @generator.debug = false
    @generator.job_collection = {}
    @generator.remote_depends = {}
  end

  describe 'initialized in before(:example)' do
    it 'creates a new generator' do
      expect(@generator.job_collection).to be_empty
      expect(@generator.module_registry).not_to be_nil
    end

    it 'accepts new jobs into the job_collection' do
      job_name = 'sample_job'
      job_type = 'project'
      job_value = {}
      @generator.job_collection[job_name] = { name: job_name, type: job_type, value: job_value }
      expect(@generator.job_collection).not_to be_empty
      expect(@generator.job_collection[job_name]).not_to be_nil
    end
  end

  describe '#debug=' do
    it 'sets debug mode to false' do
      @generator.debug = false
      expect(@generator.debug).to be false
      expect(@generator.logger.level).to eq(Logger::INFO)
    end

    it 'sets debug mode to true' do
      @generator.debug = true
      expect(@generator.debug).to be true
      expect(@generator.logger.level).to eq(Logger::DEBUG)
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
    it 'produces no errors while creating pipeline SamplePipeline with view' do
      @generator.debug = true
      job_name = 'SamplePipeline'
      path = File.expand_path('../fixtures/generator_tests/sample_pipeline', __FILE__)
      errors = @generator.bootstrap(path, job_name)
      expect(errors.empty?).to be true
      Dir["#{job_name}*.xml"].each do |file|
        File.delete(file)
      end
    end

    it 'produces no errors while creating pipeline TemplatePipeline' do
      @generator.debug = true
      job_name = 'TemplatePipeline'
      path = File.expand_path('../fixtures/generator_tests/template_pipeline', __FILE__)
      errors = @generator.bootstrap(path, job_name)
      expect(errors.empty?).to be true
      Dir["#{job_name}*.xml"].each do |file|
        File.delete(file)
      end
    end

    it 'loads extensions in remote dependencies' do
      @generator.debug = true
      job_name = 'TemplatePipeline'
      path = File.expand_path('../fixtures/generator_tests/template_pipeline', __FILE__)
      errors = @generator.bootstrap(path, job_name)
      expect(errors.empty?).to be true
      expect(@generator.module_registry.registry[:job][:wrappers].keys).to include :test_wrapper
      Dir["#{job_name}*.xml"].each do |file|
        File.delete(file)
      end
      @generator.module_registry.registry[:job][:wrappers].delete(:test_wrapper)
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
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'description' => '20.0', 'git' => '20.0' })
    end
    it 'produces no errors while creating pipeline PullRequest' do
      # Dummy data
      purge = []
      create = [
        {
          name: 'PullRequest-PR1',
          type: :project,
          value: {
            name: 'PullRequest-PR1',
            jobs: [
              '{{name}}-10-SampleJob'
            ]
          }
        }
      ]
      jobs = {
        '{{name}}-10-SampleJob' => {
          name: '{{name}}-10-SampleJob',
          type: :job,
          value: {
            name: '{{name}}-10-SampleJob',
            scm_branch: 'origin/pr/2/head',
            scm_params: {
              refspec: 'refs/pull/*:refs/remotes/origin/pr/*'
            }
          }
        }
      }
      # Run the test
      @generator.debug = true
      job_name = 'PullRequest'
      path = File.expand_path('../fixtures/generator_tests/pullrequest_pipeline', __FILE__)
      expect(JenkinsPipelineBuilder::PullRequestGenerator).to receive(:new).once.and_return(
        double(purge: purge, create: create, jobs: jobs)
      )
      success = @generator.pull_request(path, job_name)
      expect(success).to be_truthy
      Dir["#{job_name}*.xml"].each do |file|
        File.delete(file)
      end
    end
    # Things to check for
    # Fail - no PR job type found
    # Encounters failure during build process
    # Fails to purge old PR jobs from Jenkins
  end

  describe '#load_collection_from_path' do
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
      expect(@generator).to receive(:load_job_collection).once.with(view_hash, false).and_return(true)
      expect(@generator).to receive(:load_job_collection).once.with(project_hash, false).and_return(true)
      @generator.send(:load_collection_from_path, path)
    end
    it 'loads a json collection from a path' do
      path = File.expand_path('../fixtures/generator_tests/test_json_files', __FILE__)
      expect(@generator).to receive(:load_job_collection).once.with(view_hash, false).and_return(true)
      expect(@generator).to receive(:load_job_collection).once.with(project_hash, false).and_return(true)
      @generator.send(:load_collection_from_path, path)
    end
    it 'loads both yaml and json files from a path' do
      path = File.expand_path('../fixtures/generator_tests/test_combo_files', __FILE__)
      expect(@generator).to receive(:load_job_collection).once.with(view_hash, false).and_return(true)
      expect(@generator).to receive(:load_job_collection).once.with(project_hash, false).and_return(true)
      @generator.send(:load_collection_from_path, path)
    end
  end

  describe '#dump' do
    it "writes a job's config XML to a file" do
      @generator.debug = true
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

  describe '#with_overrides' do
    before :each do
      # rubocop:disable LineLength
      @generator.instance_variable_set(:@job_collection, '{{name}}-build-{{env}}' => { name: '{{name}}-build-{{env}}', type: :job, value: { name: '{{name}}-build-{{env}}', description: '{{description}}', git_branch: 'master', git_url: 'https://github.roving.com/', git_repo: 'hello-world-java', git_org: 'ahanes', scm_provider: 'git', scm_url: '{{git_repo}}', scm_branch: '{{git_branch}}', builders: [{ shell_command: "echo \"Running build...\"\n" }] } }, 'global' => { name: 'global', type: :defaults, value: { name: 'global', description: 'Do not edit this through the web!' } }, 'PushTest' => { name: 'PushTest', type: :project, value: { name: 'PushTest', git_branch: 'master', git_url: 'https://github.roving.com', git_repo: 'git@github.roving.com:ahanes/hello-world-java.git', git_org: 'ahanes', jobs: [{ :"{{name}}-build-{{env}}" => { with_overrides: [{ env: 'f1' }, { env: 'l1' }] } }, { :"{{name}}-build-{{env}}" => { with_overrides: [{ env: 'd1' }] } }] } })
      # rubocop:enable  LineLength
      @generator.instance_eval { with_override }
    end

    it 'generates correct number of jobs' do
      job_count = 0
      @generator.job_collection.each do |_, v|
        next unless v[:value][:jobs]
        job_count += v[:value][:jobs].length
      end
      expect(job_count).to be 3
    end

    it 'replaces :with_overrides job' do
      @generator.job_collection.each do |_, v|
        next unless v[:value][:jobs]
        v[:value][:jobs].each do |j|
          expect(j[:with_overrides]).to be nil
        end
      end
    end

    it 'uses all variables' do
      used_vars = []
      @generator.job_collection.each do |_, v|
        next unless v[:value][:jobs]
        v[:value][:jobs].each do |j|
          used_vars << j[j.keys[0]][:env]
        end
      end
      expect(used_vars).to include 'd1'
      expect(used_vars).to include 'l1'
      expect(used_vars).to include 'f1'
    end
  end
end
