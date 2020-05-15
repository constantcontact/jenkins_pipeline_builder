#
# Copyright (c) 2014 Constant Contact
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
    attr_accessor :no_files, :job_templates, :module_registry, :job_collection

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

    def view
      JenkinsPipelineBuilder::View.new(self)
    end

    def projects(path)
      load_job_collection path unless job_collection.loaded?
      job_collection.projects.map { |p| p[:name] }
    end

    def bootstrap(path, project_name = nil)
      logger.info "Bootstrapping pipeline from path #{path}"
      load_job_collection path unless job_collection.loaded?
      publish(project_name || job_collection.projects.first[:name])
    end

    def pull_request(path, project_name, base_branch_only = false)
      logger.info "Pull Request Generator Running from path #{path}"
      load_job_collection path unless job_collection.loaded?
      defaults = job_collection.defaults[:value]
      pr_generator = PullRequestGenerator.new defaults
      pr_generator.delete_closed_prs
      errors = []
      pr_generator.open_prs.each do |pr|
        next if base_branch_only && defaults[:git_branch] != pr[:base]

        pr_generator.convert! job_collection, pr[:number]
        error = publish(project_name)
        errors << error unless error.empty?
      end
      errors.empty?
    end

    def file(path, project_name)
      logger.info "Generating files from path #{path}"
      JenkinsPipelineBuilder.file_mode!
      bootstrap(path, project_name)
    end

    def dump(job_name)
      logger.info "Debug #{JenkinsPipelineBuilder.debug}"
      logger.info "Dumping #{job_name} into #{job_name}.xml"
      xml = client.job.get_config(job_name)
      File.open(job_name + '.xml', 'w') { |f| f.write xml }
    end

    def resolve_project(project)
      defaults = job_collection.defaults
      settings = defaults.nil? ? {} : defaults[:value] || {}
      compiler = JenkinsPipelineBuilder::Compiler.new self
      project[:settings] = compiler.get_settings_bag(project, settings)

      errors = process_project project

      print_project_errors errors
      return false, 'Encountered errors exiting' unless errors.empty?

      [true, project]
    end

    # Works for jobs, views, and promotions
    def resolve_job_by_name(name, settings = {})
      job = job_collection.get_item(name)
      raise "Failed to locate job by name '#{name}'" if job.nil?

      job_value = job[:value]
      logger.debug "Compiling job #{name}"
      compiler = JenkinsPipelineBuilder::Compiler.new self
      success, payload = compiler.compile_job(job_value, settings)
      [success, payload]
    end
    alias resolve_section_by_name resolve_job_by_name

    private

    def load_job_collection(path)
      job_collection.load_from_path(path)
      job_collection.remote_dependencies.cleanup
    end

    def publish(project_name)
      errors = if job_collection.projects.any?
                 publish_project(project_name)
               else
                 publish_jobs(job_collection.standalone_jobs)
               end
      print_compile_errors errors
      errors
    end

    def process_project(project)
      errors = {}
      project_body = project[:value]

      %i[jobs views promotions].each do |key|
        next unless project_body[key]

        Utils.symbolize_with_empty_hash!(project_body[key])
        process_job_changes!(project_body[:jobs]) if key == :jobs
        process_pipeline_section(project_body[key], project, errors)
      end

      logger.info project
      errors
    end

    def print_compile_errors(errors)
      errors.each do |k, v|
        logger.error "Encountered errors compiling '#{k}':"
        logger.error v
      end
    end

    def print_project_errors(errors)
      errors.each do |error|
        logger.error 'Encountered errors processing:'
        logger.error error.inspect
      end
    end

    def process_job_changes!(jobs)
      jobs.each do |job|
        job_id = job.keys.first
        j = job_collection.get_item(job_id)

        next unless j

        Utils.hash_merge!(j, job[job_id])
        j[:value][:name] = j[:value][:job_name] if j[:value][:job_name]
      end
    end

    def process_pipeline_section(section, project, errors = {})
      section.each do |item|
        item_id = item.keys.first
        settings = project[:settings].clone.merge(item[item_id])
        success, payload = resolve_section_by_name(item_id, settings)

        if success
          item[:result] = payload
        else
          errors[item_id] = payload
        end
      end
      errors
    end

    def create_jobs_and_views(project)
      success, payload = resolve_project(project)
      return { project[:name].to_s => 'Failed to resolve' } unless success

      logger.info 'successfully resolved project'
      compiled_project = payload

      errors = publish_jobs(compiled_project[:value][:jobs])

      publish_views(compiled_project[:value][:views]) if compiled_project[:value][:views]

      if compiled_project[:value][:promotions]
        publish_promotions(compiled_project[:value][:promotions], compiled_project[:value][:jobs])
      end
      errors
    end

    def publish_project(project_name)
      project = job_collection.projects.find { |p| p[:name] == project_name }
      create_jobs_and_views(project || raise("Project #{project_name} not found!"))
    end

    def publish_promotions(promotions, jobs)
      # Converts a list of jobs that might have a list of promoted_builds to
      # A hash of promoted_builds names => associated job names
      promotion_job_pairs = jobs.each_with_object({}) do |j, acc|
        next unless j[:result][:promoted_builds]

        j[:result][:promoted_builds].each do |promotion_name|
          acc[promotion_name] = j[:result][:name]
        end
      end

      promotions.each do |promotion|
        compiled_promotion = promotion[:result]
        associated_job_name = promotion_job_pairs[compiled_promotion[:name]]
        Promotion.new(self).create(compiled_promotion, associated_job_name)
      end
    end

    def publish_views(views)
      views.each do |view|
        compiled_view = view[:result]
        View.new(self).create(compiled_view)
      end
    end

    def publish_jobs(jobs, errors = {})
      jobs.each do |i|
        logger.info "Processing #{i}"
        job = i[:result]
        raise "Result is empty for #{i}" if job.nil?

        job = Job.new job
        success, payload = job.create_or_update
        errors[job.name] = payload unless success
      end
      errors
    end
  end
end
