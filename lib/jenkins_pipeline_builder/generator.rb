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

require 'yaml'
require 'json'

module JenkinsPipelineBuilder
  class Generator
    attr_reader :debug
    attr_accessor :no_files, :job_templates, :logger, :module_registry, :job_collection

    # Initialize a Client object with Jenkins Api Client
    #
    # @param args [Hash] Arguments to connect to Jenkins server
    #
    # @option args [String] :something some option description
    #
    # @return [JenkinsPipelineBuilder::Generator] a client generator
    #
    # @raise [ArgumentError] when required options are not provided.
    #
    def initialize
      @job_templates = {}
      @extensions = {}
      @module_registry = ModuleRegistry.new
      @job_collection = JobCollection.new
    end

    def logger
      JenkinsPipelineBuilder.logger
    end

    def client
      JenkinsPipelineBuilder.client
    end

    # Creates an instance to the View class by passing a reference to self
    #
    # @return [JenkinsApi::Client::System] An object to System subclass
    #
    def view
      JenkinsPipelineBuilder::View.new(self)
    end

    def bootstrap(path, project_name = nil)
      logger.info "Bootstrapping pipeline from path #{path}"
      job_collection.load_from_path(path)
      errors = {}
      if job_collection.projects.any?
        errors = publish_project(project_name)
      else
        errors = publish_jobs(standalone job_collection.jobs)
      end
      errors.each do |k, v|
        logger.error "Encountered errors compiling: #{k}:"
        logger.error v
      end
      errors
    end

    def pull_request(path, project_name)
      logger.info "Pull Request Generator Running from path #{path}"
      job_collection.load_from_path(path)
      logger.info "Project: #{job_collection.projects}"
      errors = {}
      job_collection.projects.each do |project|
        next unless project[:name] == project_name || project_name.nil?
        logger.info "Using Project #{project}"
        pull_job = find_pull_request_generator(project)
        next unless pull_job
        p_success, p_payload = compile_pull_request_generator(pull_job[:name], project)
        unless p_success
          errors[pull_job[:name]] = p_payload
          next
        end
        jobs = filter_pull_request_jobs(pull_job)
        pull = JenkinsPipelineBuilder::PullRequestGenerator.new(project, jobs, p_payload)
        @job_collection.collection.merge! pull.jobs
        pull_errors = create_pull_request_jobs(pull)
        errors.merge! pull_errors
        purge_pull_request_jobs(pull)
      end
      errors.each do |k, v|
        logger.error "Encountered errors compiling: #{k}:"
        logger.error v
      end
      errors.empty?
    end

    def file(path, project_name)
      logger.info "Generating files from path #{path}"
      JenkinsPipelineBuilder.file_mode!
      bootstrap(path, project_name)
    end

    def dump(job_name)
      @logger.info "Debug #{@debug}"
      @logger.info "Dumping #{job_name} into #{job_name}.xml"
      xml = client.job.get_config(job_name)
      File.open(job_name + '.xml', 'w') { |f| f.write xml }
    end

    #
    # BEGIN PRIVATE METHODS
    #

    private

    # Converts standalone jobs to the format that they have when loaded as part of a project.
    # This addresses an issue where #pubish_jobs assumes that each job will be wrapped
    # with in a hash a referenced under a key called :result, which is what happens when
    # it is loaded as part of a project.
    #
    # @return An array of jobs
    #
    def standalone(jobs)
      jobs.map! { |job| { result: job } }
    end

    def purge_pull_request_jobs(pull)
      pull.purge.each do |purge_job|
        jobs = client.job.list "#{purge_job}.*"
        jobs.each do |job|
          client.job.delete job
        end
      end
    end

    def create_pull_request_jobs(pull)
      errors = {}
      pull.create.each do |pull_project|
        success, compiled_project = resolve_project(pull_project)
        compiled_project[:value][:jobs].each do |i|
          job = i[:result]
          job = Job.new job
          success, payload = job.create_or_update
          errors[job.name] = payload unless success
        end
      end
      errors
    end

    def find_pull_request_generator(project)
      project_jobs = project[:value][:jobs] || []
      pull_job = nil
      project_jobs.each do |job|
        job = job.keys.first if job.is_a? Hash
        job = @job_collection.collection[job.to_s]
        pull_job = job if job[:value][:job_type] == 'pull_request_generator'
      end
      pull_job
    end

    def filter_pull_request_jobs(pull_job)
      jobs = {}
      pull_jobs = pull_job[:value][:jobs] || []
      pull_jobs.each do |job|
        if job.is_a? String
          jobs[job.to_s] = @job_collection.collection[job.to_s]
        else
          jobs[job.keys.first.to_s] = @job_collection.collection[job.keys.first.to_s]
        end
      end
      fail 'No jobs found for pull request' if jobs.empty?
      jobs
    end

    def compile_pull_request_generator(pull_job, project)
      defaults = job_collection.defaults
      settings = defaults.nil? ? {} : defaults[:value] || {}
      settings = Compiler.get_settings_bag(project, settings)
      resolve_job_by_name(pull_job, settings)
    end

    def prepare_jobs(jobs)
      jobs.map! do |job|
        job.is_a?(String) ? { job.to_sym => {} } : job
      end
    end

    def process_job_changes(jobs)
      jobs.each do |job|
        job_id = job.keys.first
        j = job_collection.get_item(job_id)

        next unless j

        Utils.hash_merge!(j, job[job_id])
        j[:value][:name] = j[:value][:job_name] if j[:value][:job_name]
      end
    end

    def process_views(views, project, errors = {})
      views.map! do |view|
        view.is_a?(String) ? { view.to_sym => {} } : view
      end
      views.each do |view|
        view_id = view.keys.first
        settings = project[:settings].clone.merge(view[view_id])
        # TODO: rename resolve_job_by_name properly
        success, payload = resolve_job_by_name(view_id, settings)
        if success
          view[:result] = payload
        else
          errors[view_id] = payload
        end
      end
      errors
    end

    def resolve_project(project)
      defaults = job_collection.defaults
      settings = defaults.nil? ? {} : defaults[:value] || {}
      project[:settings] = Compiler.get_settings_bag(project, settings) unless project[:settings]
      project_body = project[:value]

      jobs = prepare_jobs(project_body[:jobs]) if project_body[:jobs]
      logger.info project
      process_job_changes(jobs)
      errors = process_jobs(jobs, project)
      errors = process_views(project_body[:views], project, errors) if project_body[:views]
      errors.each do |k, v|
        puts "Encountered errors processing: #{k}:"
        v.each do |key, error|
          puts "  key: #{key} had the following error:"
          puts "  #{error.inspect}"
        end
      end
      return false, 'Encountered errors exiting' unless errors.empty?

      [true, project]
    end

    def process_jobs(jobs, project, errors = {})
      jobs.each do |job|
        job_id = job.keys.first
        settings = project[:settings].clone.merge(job[job_id])
        success, payload = resolve_job_by_name(job_id, settings)
        if success
          job[:result] = payload
        else
          errors[job_id] = payload
        end
      end
      errors
    end

    def resolve_job_by_name(name, settings = {})
      job = job_collection.get_item(name)
      fail "Failed to locate job by name '#{name}'" if job.nil?
      job_value = job[:value]
      logger.debug "Compiling job #{name}"
      success, payload = Compiler.compile(job_value, settings, @job_collection.collection)
      [success, payload]
    end

    def publish_project(project_name, errors = {})
      job_collection.projects.each do |project|
        next unless project_name.nil? || project[:name] == project_name
        success, payload = resolve_project(project)
        if success
          logger.info 'successfully resolved project'
          compiled_project = payload
        else
          return { project_name: 'Failed to resolve' }
        end

        errors = publish_jobs(compiled_project[:value][:jobs]) if compiled_project[:value][:jobs]
        next unless compiled_project[:value][:views]
        compiled_project[:value][:views].each do |v|
          compiled_view = v[:result]
          view.create(compiled_view)
        end
      end
      errors
    end

    def publish_jobs(jobs, errors = {})
      jobs.each do |i|
        logger.info "Processing #{i}"
        job = i[:result]
        fail "Result is empty for #{i}" if job.nil?
        job = Job.new job
        success, payload = job.create_or_update
        errors[job.name] = payload unless success
      end
      errors
    end
  end
end
