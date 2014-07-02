require File.expand_path('../spec_helper', __FILE__)

describe JenkinsPipelineBuilder::Generator do 

  before(:all) do 
    JenkinsPipelineBuilder.credentials = {
      server_ip: '127.0.0.1',
      server_port: 8080,
      username: 'username',
      password: 'password',
      log_location: '/dev/null'
    }
    JenkinsPipelineBuilder.client
    @generator = JenkinsPipelineBuilder.generator
  end

  after(:each) do
    @generator.debug = false
    @generator.job_templates = {}
    @generator.job_collection = {}
    @generator.remote_depends = {}
  end

  describe 'initialized in before(:example)' do
    it "creates a new generator" do
      # expect(@generator.job_templates).to be_empty
      expect(@generator.job_collection).to be_empty
      # expect(@generator.extensions).to be_empty
      # expect(@generator.remote_depends).to be_empty
      expect(@generator.module_registry).not_to be_nil
    end

    it "accepts new jobs into the job_collection" do
      job_name = "sample_job"
      job_type = "project"
      job_value = {}
      @generator.job_collection[job_name] = { name: job_name, type: job_type, value: job_value }
      expect(@generator.job_collection).not_to be_empty
      expect(@generator.job_collection[job_name]).not_to be_nil
    end
  end

  describe '#debug=' do
    it "sets debug mode to false" do
      @generator.debug = false
      expect(@generator.debug).to be false
      expect(@generator.logger.level).to eq(Logger::INFO)
    end

    it "sets debug mode to true" do
      @generator.debug = true
      expect(@generator.debug).to be true
      expect(@generator.logger.level).to eq(Logger::DEBUG)
    end
  end

  describe '#client' do
    it "returns the singleton JenkinsPipelineBuilder.client object" do
      expect(@generator.client).to be(JenkinsPipelineBuilder.client)
    end
  end

  describe '#view' do
    it "returns a new JenkinsPipelineBuilder::View object" do
      view = @generator.view
      expect(view).not_to be_nil
      # expect(view.generator).to be(@generator)
    end
  end

  describe '#bootstrap' do

    # it "AAAAAAAA" do
    #   dbl = double
    #   allow(dbl).to receive(:download_yaml)
    #   expect(dbl.download_yaml).to be_nil
    # end

    it "produces no errors while creating pipeline SamplePipeline" do
      @generator.debug = true
      job_name = 'SamplePipeline'
      path = File.expand_path("../fixtures/generator_tests/sample_pipeline", __FILE__)
      errors = @generator.bootstrap(path, job_name)
      expect(errors.empty?).to be true
      Dir["#{job_name}*.xml"].each do |file|
        File.delete(file)
      end
    end

    it "produces no errors while creating pipeline TemplatePipeline" do
      @generator.debug = true
      job_name = 'TemplatePipeline'
      path = File.expand_path("../fixtures/generator_tests/template_pipeline", __FILE__)
      stub_request(:get, "https://github.roving.com/devops/jenkins-pipeline-templates/archive.master.tar.gz").
        with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
        to_return(:status => 200, :body => "", :headers => {})
      errors = @generator.bootstrap(path, job_name)
      expect(errors.empty?).to be true
      Dir["#{job_name}*.xml"].each do |file|
        File.delete(file)
      end
    end
    # Things to check for:
    # Fail - Finds duplicate job names (load_job_collection)
    # Extension fails to register?
    # resolve_project returns false
    # Accumulates errors in publish_project/job path
  end

  describe '#pull_request' do
    it "produces no errors while creating pipeline PullRequest" do
      @generator.debug = true
      job_name = 'PullRequest'
      path = File.expand_path("../fixtures/generator_tests/pullrequest_pipeline", __FILE__)
      # stub_request(:get, "http://github.comapi/v3/repos/bencentra/generator_tests/pulls").
      #    with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'github.comapi', 'User-Agent'=>'Ruby'}).
      #    to_return(:status => 200, :body => "", :headers => {})
      success = @generator.pull_request(path, job_name)
      expect(success).to be_truthy
      Dir["#{job_name}*.xml"].each do |file|
        # File.delete(file)
      end
    end
    # Things to check for
    # Fail - no PR job type found
    # Encounters failure during build process
    # Fails to purge old PR jobs from Jenkins
  end

  describe '#dump' do
    it "writes a job's config XML to a file" do
      @generator.debug = true
      job_name = "test_job"
      body = ""
      test_path = File.expand_path("../fixtures/generator_tests", __FILE__)
      File.open("#{test_path}/#{job_name}.xml", "r") do |f|
        f.each_line do |line|
          body << line
        end
      end
      stub_request(:get, "http://username:password@127.0.0.1:8080/job/test_job/config.xml").
         with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent'=>'Ruby'}).
         to_return(:status => 200, :body => "#{body}", :headers => {})
      @generator.dump(job_name) # This method uses client. Do we want to stub this somehow?
      expect(File.exists?("#{job_name}.xml")).to be true
      File.delete("#{job_name}.xml")
    end
  end
end