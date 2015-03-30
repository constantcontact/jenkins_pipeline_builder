#
# Copyright (c) 2014 Constant Contact
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

module JenkinsPipelineBuilder
  class PullRequestGenerator
    attr_reader :purge, :create, :jobs, :project, :generator, :pull_generator, :errors, :pull_requests

    def initialize(project, generator)
      @project = project
      @generator = generator

      @purge = []
      @create = []

      @errors = {}
      @pull_generator = find
      success, payload = compile_generator
      unless success
        @errors[@pull_generator[:name]] = payload
        return false
      end
      @jobs = filter_jobs

      # old init
      @pull_requests = check_for_pull payload
      find_old_pull_requests
      generate_pull_requests

      @generator.job_collection.collection.merge! @jobs
      @errors.merge! create_jobs

      purge_jobs
    end

    def valid?
      errors.empty?
    end

    private

    def generate_pull_requests
      @pull_requests.each do |number|
        req = JenkinsPipelineBuilder::PullRequest.new(project, number, jobs, @pull_generator)
        @jobs.merge! req.jobs
        project_new = req.project

        # Overwrite the jobs from the generator to the project
        project_new[:value][:jobs] = req.jobs.keys
        @create << project_new
      end
    end

    def purge_jobs
      purge.each do |purge_job|
        jobs = JenkinsPipelineBuilder.client.job.list "#{purge_job}.*"
        jobs.each do |job|
          JenkinsPipelineBuilder.client.job.delete job
        end
      end
    end

    def create_jobs
      errors = {}
      create.each do |pull_project|
        success, compiled_project = generator.resolve_project(pull_project)
        compiled_project[:value][:jobs].each do |i|
          job = i[:result]
          job = Job.new job
          success, payload = job.create_or_update
          errors[job.name] = payload unless success
        end
      end
      errors
    end

    def filter_jobs
      jobs = {}
      pull_jobs = pull_generator[:value][:jobs] || []
      pull_jobs.each do |job|
        if job.is_a? String
          jobs[job.to_s] = generator.job_collection.collection[job.to_s]
        else
          jobs[job.keys.first.to_s] = generator.job_collection.collection[job.keys.first.to_s]
        end
      end
      fail 'No jobs found for pull request' if jobs.empty?
      jobs
    end

    def compile_generator
      defaults = generator.job_collection.defaults
      settings = defaults.nil? ? {} : defaults[:value] || {}
      compiler = Compiler.new generator
      settings = compiler.get_settings_bag(project, settings)
      generator.resolve_job_by_name(pull_generator[:name], settings)
    end

    def find
      project_jobs = project[:value][:jobs] || []
      pull_job = nil
      project_jobs.each do |job|
        job = job.keys.first if job.is_a? Hash
        job = generator.job_collection.collection[job.to_s]

        pull_job = job if job[:value][:job_type] == 'pull_request_generator'
      end
      fail 'No jobs of type pull_request_generator found' unless pull_job
      pull_job
    end

    # Check for Github Pull Requests
    #
    # args[:git_url] URL to the github main page ex. https://www.github.com/
    # args[:git_repo] Name of repo only, not url  ex. jenkins_pipeline_builder
    # args[:git_org] The Orig user ex. constantcontact
    # @return = array of pull request numbers
    def check_for_pull(args)
      fail 'Please specify all arguments' unless args[:git_url] && args[:git_org] && args[:git_repo]
      # Build the Git URL
      git_url = "#{args[:git_url]}api/v3/repos/#{args[:git_org]}/#{args[:git_repo]}/pulls"

      # Download the JSON Data from the API
      resp = Net::HTTP.get_response(URI.parse(git_url))
      pulls = JSON.parse(resp.body)
      pulls.map { |p| p['number'] }
    end

    def find_old_pull_requests
      reqs = pull_requests.clone.map { |req| "#{project[:name]}-PR#{req}" }
      # Read File
      # FIXME: Shouldn't this be opening just with read permissions?
      old_requests = File.new('pull_requests.csv', 'a+').read.split(',')

      # Pop off current pull requests
      old_requests.delete_if { |req| reqs.include?("#{req}") }
      @purge = old_requests

      # Write File
      File.open('pull_requests.csv', 'w+') { |file| file.write reqs.join(',') }
    end
  end
end
