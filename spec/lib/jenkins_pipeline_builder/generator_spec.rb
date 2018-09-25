require File.expand_path('spec_helper', __dir__)

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
        list_installed: { 'description' => '20.0', 'git' => '20.0' }
      )
    end

    def bootstrap(fixture_path, job_name)
      JenkinsPipelineBuilder.debug!
      @generator.bootstrap(fixture_path, job_name)
    end

    def fixture_path(fixture)
      File.expand_path("../fixtures/generator_tests/#{fixture}", __FILE__)
    end

    it 'works with no project specified' do
      expect(@generator).to receive(:create_jobs_and_views).and_return({})
      errors = bootstrap(fixture_path('sample_pipeline'), nil)
      expect(errors).to be_empty
    end

    it 'raises an error when a specified project does not exist' do
      expect { bootstrap(fixture_path('sample_pipeline'), 'Nopers') }.to raise_error
    end

    it 'produces no errors while creating pipeline SamplePipeline with view' do
      errors = bootstrap(fixture_path('sample_pipeline'), 'SamplePipeline')
      expect(errors).to be_empty
    end

    it 'produces no errors while creating a single job' do
      errors = bootstrap(fixture_path('sample_pipeline/SamplePipeline-10-Commit.yaml'), 'SamplePipeline-10-Commit')
      expect(errors).to be_empty
    end

    context 'when creating pipeline templates' do
      before(:each) do
        tar_path = File.join(__dir__, 'fixtures/generator_tests/template_pipeline/jobs.tar.gz')
        parsed_url = URI.parse('https://www.test.com')
        file_contents = Zlib::GzipReader.new(File.open(tar_path)).read
        file_object = double
        allow(URI).to receive(:parse).and_return(parsed_url)
        allow(parsed_url).to receive(:open).and_yield('A String')
        allow(Zlib::GzipReader).to receive(:new).and_return(file_object)
        allow(file_object).to receive(:read).and_return(file_contents)
      end

      it 'produces no errors while creating pipeline TemplatePipeline' do
        errors = bootstrap(fixture_path('template_pipeline'), 'TemplatePipeline')
        expect(errors).to be_empty
      end

      it 'overrides the remote dependencies with local ones' do
        errors = bootstrap(fixture_path('local_override/remote_and_local'), 'TemplatePipeline')
        expect(errors).to be_empty
        expect(@generator.job_collection.collection['{{name}}-10'][:value][:description]).to eq('Overridden stuff')
      end

      it 'loads extensions in remote dependencies' do
        errors = bootstrap(fixture_path('template_pipeline'), 'TemplatePipeline')
        expect(errors).to be_empty
        expect(@generator.module_registry.registry[:job][:wrappers].keys).to include :test_wrapper
        @generator.module_registry.registry[:job][:wrappers].delete(:test_wrapper)
      end

      it 'fails to override when there are duplicate local items' do
        expect { bootstrap(fixture_path('local_override/all_local'), 'TemplatePipeline') }.to raise_error(StandardError)
      end

      it 'produces no errors while creating pipeline TemplatePipeline_nested' do
        tar_path = File.join(__dir__, 'fixtures/generator_tests/template_pipeline_nested/jobs.tar.gz')
        parsed_url = URI.parse('https://www.test.com')
        file_contents = Zlib::GzipReader.new(File.open(tar_path)).read
        file_object = double
        allow(URI).to receive(:parse).and_return(parsed_url)
        allow(parsed_url).to receive(:open).and_yield('A String')
        allow(Zlib::GzipReader).to receive(:new).and_return(file_object)
        allow(file_object).to receive(:read).and_return(file_contents)
        errors = bootstrap(fixture_path('template_pipeline_nested'), 'TemplatePipeline_nested')
        expect(errors).to be_empty
      end
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

    let(:pr_master) { { number: 1, base: 'master' } }
    let(:pr_not_master) { { number: 2, base: 'not-master' } }
    let(:open_prs) { [pr_master, pr_not_master] }
    let(:path) { File.expand_path('fixtures/generator_tests/pullrequest_pipeline', __dir__) }
    it 'produces no errors while creating pipeline PullRequest' do
      job_name = 'PullRequest'
      pr_generator = double('pr_generator')
      expect(JenkinsPipelineBuilder::PullRequestGenerator).to receive(:new)
        .with(hash_including(application_name: 'testapp',
                             github_site: 'https://github.com',
                             git_org: 'testorg',
                             git_repo_name: 'generator_tests'))
        .and_return(pr_generator)
      expect(pr_generator).to receive(:delete_closed_prs)
      expect(pr_generator).to receive(:convert!)
      expect(pr_generator).to receive(:open_prs).and_return [pr_master]
      success = @generator.pull_request(path, job_name)
      expect(success).to be_truthy
    end

    it 'correctly creates jobs when there are multiple pulls open' do
      job_name = 'PullRequest'
      pr_generator = double('pr_generator')
      expect(JenkinsPipelineBuilder::PullRequestGenerator).to receive(:new)
        .with(hash_including(application_name: 'testapp',
                             github_site: 'https://github.com',
                             git_org: 'testorg',
                             git_repo_name: 'generator_tests'))
        .and_return(pr_generator)
      expect(pr_generator).to receive(:delete_closed_prs)
      expect(pr_generator).to receive(:convert!).twice
      expect(pr_generator).to receive(:open_prs).and_return open_prs
      expect(@generator.pull_request(path, job_name)).to be_truthy
    end

    it 'refreshes the project settings everytime' do
      job_name = 'PullRequest'
      pr_generator = double('pr_generator')
      expect(JenkinsPipelineBuilder::PullRequestGenerator).to receive(:new)
        .with(hash_including(application_name: 'testapp',
                             github_site: 'https://github.com',
                             git_org: 'testorg',
                             git_repo_name: 'generator_tests'))
        .and_return(pr_generator)
      expect(pr_generator).to receive(:delete_closed_prs)
      allow(pr_generator).to receive(:convert!) do |job_collection, pr_number|
        job_collection.defaults[:value][:application_name] = "testapp-PR#{pr_number}"
      end
      expect(pr_generator).to receive(:open_prs).and_return open_prs
      expect(@generator.pull_request(path, job_name)).to be_truthy
      expect(@generator.job_collection.projects.first[:settings][:application_name]).to eq 'testapp-PR2'
    end

    it 'correctly creates jobs only for the base branch' do
      job_name = 'PullRequest'
      pr_generator = double('pr_generator')
      expect(JenkinsPipelineBuilder::PullRequestGenerator).to receive(:new)
        .with(hash_including(
                application_name: 'testapp',
                github_site: 'https://github.com',
                git_org: 'testorg',
                git_repo_name: 'generator_tests'
              )).and_return(pr_generator)

      expect(pr_generator).to receive(:open_prs).and_return open_prs
      expect(pr_generator).to receive(:delete_closed_prs)
      expect(pr_generator).to receive(:convert!)
        .with(instance_of(JenkinsPipelineBuilder::JobCollection), pr_master[:number])
        .once

      expect(@generator.pull_request(path, job_name, true)).to be_truthy
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
        {
          'name' => '{{name}} View',
          'type' => 'listview',
          'description' => '{{description}}',
          'regex' => '{{name}}.*'
        } }]
    end

    it 'loads a yaml collection from a path' do
      path = File.expand_path('fixtures/generator_tests/test_yaml_files', __dir__)
      @generator.job_collection.load_from_path path
    end
    it 'loads a json collection from a path' do
      path = File.expand_path('fixtures/generator_tests/test_json_files', __dir__)
      @generator.job_collection.load_from_path path
    end
    it 'loads both yaml and json files from a path' do
      path = File.expand_path('fixtures/generator_tests/test_combo_files', __dir__)
      @generator.job_collection.load_from_path path
    end

    it 'errors when reading a bad yaml file' do
      path = File.expand_path('fixtures/generator_tests/test_bad_yaml_files', __dir__)
      expect { @generator.job_collection.load_from_path path }.to raise_error(
        CustomErrors::ParseError, /There was an error while parsing a file/
      )
    end
    it 'errors when reading a bad json file' do
      path = File.expand_path('fixtures/generator_tests/test_bad_json_files', __dir__)
      expect { @generator.job_collection.load_from_path path }.to raise_error(
        CustomErrors::ParseError, /There was an error while parsing a file/
      )
    end
  end

  describe '#dump' do
    it "writes a job's config XML to a file" do
      allow(JenkinsPipelineBuilder).to receive(:debug).and_return true
      job_name = 'test_job'
      body = ''
      test_path = File.expand_path('fixtures/generator_tests', __dir__)
      File.open("#{test_path}/#{job_name}.xml", 'r') do |f|
        f.each_line do |line|
          body << line
        end
      end
      stub_request(:get, 'http://username:password@127.0.0.1:8080/job/test_job/config.xml')
        .to_return(status: 200, body: body.to_s, headers: {})
      @generator.dump(job_name)
      expect(File.exist?("#{job_name}.xml")).to be true
      File.delete("#{job_name}.xml")
    end
  end

  describe '#projects' do
    it 'returns a list of projects' do
      path = File.expand_path('fixtures/generator_tests/multi_project', __dir__)
      expect(@generator.projects(path)).to eq %w[SamplePipeline1 SamplePipeline2 SamplePipeline3]
    end
  end

  describe '#file_mode' do
    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'description' => '20.0', 'git' => '20.0' }
      )
    end
    after :each do
      file_paths = ['out/xml/TemplatePipeline-10.xml',
                    'out/xml/TemplatePipeline-11.xml']
      file_paths.each do |file_path|
        File.delete(file_path) if File.exist?(file_path)
      end
    end

    it 'generates xml and saves to disk without sending jobs to the server' do
      tar_path = File.join(__dir__, 'fixtures/generator_tests/template_pipeline_nested/jobs.tar.gz')
      parsed_url = URI.parse('https://www.test.com')
      file_contents = Zlib::GzipReader.new(File.open(tar_path)).read
      file_object = double
      allow(URI).to receive(:parse).and_return(parsed_url)
      allow(parsed_url).to receive(:open).and_yield('A String')
      allow(Zlib::GzipReader).to receive(:new).and_return(file_object)
      allow(file_object).to receive(:read).and_return(file_contents)

      job_name = 'TemplatePipeline'
      path = File.expand_path('fixtures/generator_tests/template_pipeline', __dir__)
      errors = @generator.file(path, job_name)
      expect(errors).to be_empty
      expect(File.exist?("out/xml/#{job_name}-10.xml")).to be true
      expect(File.exist?("out/xml/#{job_name}-11.xml")).to be true
    end
  end
end
