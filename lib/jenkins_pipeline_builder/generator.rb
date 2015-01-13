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
    attr_accessor :no_files, :job_templates, :job_collection, :logger, :module_registry, :remote_depends

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
      @job_collection = {}
      @extensions = {}
      @remote_depends = {}
      @module_registry = ModuleRegistry.new
    end

    def debug=(value)
      @debug = value
      logger.level = (value) ? Logger::DEBUG : Logger::INFO
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
      load_collection_from_path(path)
      cleanup_temp_remote
      errors = {}
      if projects.any?
        errors = publish_project(project_name)
      else
        errors = publish_jobs(jobs)
      end
      errors.each do |k, v|
        logger.error "Encountered errors compiling: #{k}:"
        logger.error v
      end
      errors
    end

    def pull_request(path, project_name)
      failed = false
      logger.info "Pull Request Generator Running from path #{path}"
      load_collection_from_path(path)
      cleanup_temp_remote
      logger.info "Project: #{projects}"
      projects.each do |project|
        next unless project[:name] == project_name || project_name.nil?
        logger.info "Using Project #{project}"
        pull_job = find_pull_request_generator(project)
        p_success, p_payload = compile_pull_request_generator(pull_job[:name], project)
        next unless p_success
        jobs = filter_pull_request_jobs(pull_job)
        pull = JenkinsPipelineBuilder::PullRequestGenerator.new(project, jobs, p_payload)
        @job_collection.merge! pull.jobs
        success = create_pull_request_jobs(pull)
        failed = success unless success
        purge_pull_request_jobs(pull)
      end
      !failed
    end

    def file(path, project_name)
      logger.info "Generating files from path #{path}"
      @file_mode = true
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

    def purge_pull_request_jobs(pull)
      pull.purge.each do |purge_job|
        jobs = client.job.list "#{purge_job}.*"
        jobs.each do |job|
          client.job.delete job
        end
      end
    end

    def create_pull_request_jobs(pull)
      success = false
      pull.create.each do |pull_project|
        success, compiled_project = resolve_project(pull_project)
        compiled_project[:value][:jobs].each do |i|
          job = i[:result]
          success, payload = compile_job_to_xml(job)
          create_or_update(job, payload) if success
        end
      end
      success
    end

    def find_pull_request_generator(project)
      project_jobs = project[:value][:jobs] || []
      pull_job = nil
      project_jobs.each do |job|
        job = job.keys.first if job.is_a? Hash
        job = @job_collection[job.to_s]
        pull_job = job if job[:value][:job_type] == 'pull_request_generator'
      end
      fail 'No Pull Request Job Found for Project' unless pull_job
      pull_job
    end

    def filter_pull_request_jobs(pull_job)
      jobs = {}
      pull_jobs = pull_job[:value][:jobs] || []
      pull_jobs.each do |job|
        if job.is_a? String
          jobs[job.to_s] = @job_collection[job.to_s]
        else
          jobs[job.keys.first.to_s] = @job_collection[job.keys.first.to_s]
        end
      end
      fail 'No jobs found for pull request' if jobs.empty?
      jobs
    end

    def compile_pull_request_generator(pull_job, project)
      defaults = get_item('global')
      settings = defaults.nil? ? {} : defaults[:value] || {}
      settings = Compiler.get_settings_bag(project, settings)
      resolve_job_by_name(pull_job, settings)
    end

    def load_collection_from_path(path, remote = false)
      load_extensions(path)
      path = File.expand_path(path, Dir.getwd)
      if File.directory?(path)
        logger.info "Generating from folder #{path}"
        Dir[File.join(path, '/*.{yaml,yml}')].each do |file|
          logger.info "Loading file #{file}"
          yaml = YAML.load_file(file)
          load_job_collection(yaml, remote)
        end
        Dir[File.join(path, '/*.json')].each do |file|
          logger.info "Loading file #{file}"
          json = JSON.parse(IO.read(file))
          load_job_collection(json, remote)
        end
      else
        logger.info "Loading file #{path}"
        if path.end_with? 'json'
          hash = JSON.parse(IO.read(path))
        else  # elsif path.end_with?("yml") || path.end_with?("yaml")
          hash = YAML.load_file(path)
        end
        load_job_collection(hash, remote)
      end
    end

    def load_job_collection(yaml, remote = false)
      yaml.each do |section|
        Utils.symbolize_keys_deep!(section)
        key = section.keys.first
        value = section[key]
        if key == :dependencies
          logger.info 'Resolving Dependencies for remote project'
          load_remote_files(value)
          next
        end
        name = value[:name]
        if @job_collection.key?(name)
          if remote
            logger.info "Duplicate item with name '#{name}' was detected from the remote folder."
          else
            fail "Duplicate item with name '#{name}' was detected."
          end
        else
          @job_collection[name.to_s] = { name: name.to_s, type: key, value: value }
        end
      end
    end

    def get_item(name)
      @job_collection[name.to_s]
    end

    def load_extensions(path)
      path = "#{path}/extensions"
      path = File.expand_path(path, Dir.getwd)
      return unless File.directory?(path)
      logger.info "Loading extensions from folder #{path}"
      logger.info Dir.glob("#{path}/*.rb").inspect
      Dir.glob("#{path}/*.rb").each do |file|
        logger.info "Loaded #{file}"
        require file
      end
    end

    def load_template(path, template)
      # If we specify what folder the yaml is in, load that
      if template[:folder]
        path = File.join(path, template[:folder])
      else
        path = File.join(path, template[:name]) unless template[:name] == 'default'
        # If we are looking for the newest version or no version was set
        if (template[:version].nil? || template[:version] == 'newest') && File.directory?(path)
          folders = Dir.entries(path)
          highest = folders.max
          template[:version] = highest unless highest == 0
        end
        path = File.join(path, template[:version]) unless template[:version].nil?
        path = File.join(path, 'pipeline')
      end

      if File.directory?(path)
        logger.info "Loading from #{path}"
        load_collection_from_path(path, true)
        true
      else
        false
      end
    end

    def download_yaml(url, file, remote_opts = {})
      @remote_depends[url] = file
      logger.info "Downloading #{url} to #{file}.tar"
      open("#{file}.tar", 'w') do |local_file|
        open(url, remote_opts) do |remote_file|
          local_file.write(Zlib::GzipReader.new(remote_file).read)
        end
      end

      # Extract Tar.gz to 'remote' folder
      logger.info "Unpacking #{file}.tar to #{file} folder"
      Archive::Tar::Minitar.unpack("#{file}.tar", file)
    end

    def load_remote_files(dependencies)
      ### Load remote YAML
      # Download Tar.gz
      dependencies.each do |source|
        source = source[:source]
        url = source[:url]

        file = "remote-#{@remote_depends.length}"
        if @remote_depends[url]
          file = @remote_depends[url]
        else
          opts = {}
          opts = { ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE } if source[:verify_ssl] == false
          download_yaml(url, file, opts)
        end

        path = File.expand_path(file, Dir.getwd)
        # Load templates recursively
        unless source[:templates]
          logger.info 'No specific template specified'
          # Try to load the folder or the pipeline folder
          path = File.join(path, 'pipeline') if Dir.entries(path).include? 'pipeline'
          return load_collection_from_path(path)
        end

        load_templates(path, source[:templates])
      end
    end

    def load_templates(path, templates)
      templates.each do |template|
        version = template[:version] || 'newest'
        logger.info "Loading #{template[:name]} at version #{version}"
        # Move into the remote folder and look for the template folder
        remote = Dir.entries(path)
        if remote.include? template[:name]
          # We found the template name, load this path
          logger.info 'We found the template!'
          load_template(path, template)
        else
          # Many cases we must dig one layer deep
          remote.each do |file|
            load_template(File.join(path, file), template)
          end
        end
      end
    end

    def cleanup_temp_remote
      @remote_depends.each_value do |file|
        FileUtils.rm_r file
        FileUtils.rm_r "#{file}.tar"
      end
    end

    def list_plugins
      client.plugin.list_installed
    end

    def prepare_jobs(jobs)
      jobs.map! do |job|
        job.is_a?(String) ? { job.to_sym => {} } : job
      end
    end

    def process_job_changes(jobs)
      jobs.each do |job|
        job_id = job.keys.first
        j = get_item(job_id)

        next unless j

        Utils.hash_merge!(j, job[job_id])
        j[:value][:name] = j[:job_name] if j[:job_name]
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

    def resolve_project(project)
      defaults = find_defaults
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

    def find_defaults
      @job_collection.each_value do |item|
        return item if item[:type] == 'defaults' || item[:type] == :defaults
      end
      # This is here for historical purposes
      get_item('global')
    end

    def resolve_job_by_name(name, settings = {})
      job = get_item(name)
      fail "Failed to locate job by name '#{name}'" if job.nil?
      job_value = job[:value]
      logger.debug "Compiling job #{name}"
      success, payload = Compiler.compile(job_value, settings, @job_collection)
      [success, payload]
    end

    def projects
      result = []
      @job_collection.values.each do |item|
        result << item if item[:type] == :project
      end
      result
    end

    def jobs
      result = []
      @job_collection.values.each do |item|
        result << item if item[:type] == :job
      end
      result
    end

    def publish_project(project_name, errors = {})
      projects.each do |project|
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
        success, payload = compile_job_to_xml(job)
        if success
          create_or_update(job, payload)
        else
          errors[job[:name]] = payload
        end
      end
      errors
    end

    def create_or_update(job, xml)
      job_name = job[:name]
      if @debug || @file_mode
        logger.info "Will create job #{job}"
        logger.info "#{xml}" if @debug
        FileUtils.mkdir_p(out_dir) unless File.exist?(out_dir)
        File.open("#{out_dir}/#{job_name}.xml", 'w') { |f| f.write xml }
        return
      end

      if client.job.exists?(job_name)
        client.job.update(job_name, xml)
      else
        client.job.create(job_name, xml)
      end
    end

    def compile_job_to_xml(job)
      fail 'Job name is not specified' unless job[:name]

      logger.info "Creating Yaml Job #{job}"
      job[:job_type] = 'free_style' unless job[:job_type]
      case job[:job_type]
      when 'job_dsl'
        xml = compile_freestyle_job_to_xml(job)
        payload = update_job_dsl(job, xml)
      when 'multi_project'
        xml = compile_freestyle_job_to_xml(job)
        payload = adjust_multi_project xml
      when 'build_flow'
        xml = compile_freestyle_job_to_xml(job)
        payload = add_job_dsl(job, xml)
      when 'free_style', 'pull_request_generator'
        payload = compile_freestyle_job_to_xml job
      else
        return false, "Job type: #{job[:job_type]} is not one of job_dsl, multi_project, build_flow or free_style"
      end

      [true, payload]
    end

    def adjust_multi_project(xml)
      n_xml = Nokogiri::XML(xml)
      root = n_xml.root
      root.name = 'com.tikal.jenkins.plugins.multijob.MultiJobProject'
      n_xml.to_xml
    end

    def compile_freestyle_job_to_xml(params)
      if params.key?(:template)
        template_name = params[:template]
        fail "Job template '#{template_name}' can't be resolved." unless @job_templates.key?(template_name)
        params.delete(:template)
        template = @job_templates[template_name]
        puts "Template found: #{template}"
        params = template.deep_merge(params)
        puts "Template merged: #{template}"
      end

      xml = client.job.build_freestyle_config(params)
      n_xml = Nokogiri::XML(xml, &:noblanks)

      logger.debug 'Loading the required modules'
      @module_registry.traverse_registry_path('job', params, n_xml)
      logger.debug 'Module loading complete'

      n_xml.to_xml
    end

    def add_job_dsl(job, xml)
      n_xml = Nokogiri::XML(xml)
      n_xml.root.name = 'com.cloudbees.plugins.flow.BuildFlow'
      Nokogiri::XML::Builder.with(n_xml.root) do |b_xml|
        b_xml.dsl job[:build_flow]
      end
      n_xml.to_xml
    end

    # TODO: make sure this is tested
    def update_job_dsl(job, xml)
      n_xml = Nokogiri::XML(xml)
      n_builders = n_xml.xpath('//builders').first
      Nokogiri::XML::Builder.with(n_builders) do |b_xml|
        build_job_dsl(job, b_xml)
      end
      n_xml.to_xml
    end

    def generate_job_dsl_body(params)
      logger.info 'Generating pipeline'

      xml = client.job.build_freestyle_config(params)

      n_xml = Nokogiri::XML(xml)
      if n_xml.xpath('//javaposse.jobdsl.plugin.ExecuteDslScripts').empty?
        p_xml = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |b_xml|
          build_job_dsl(params, b_xml)
        end

        n_xml.xpath('//builders').first.add_child("\r\n" + p_xml.doc.root.to_xml(indent: 4) + "\r\n")
        xml = n_xml.to_xml
      end
      xml
    end

    def build_job_dsl(job, xml)
      xml.send('javaposse.jobdsl.plugin.ExecuteDslScripts') do
        if job.key?(:job_dsl)
          xml.scriptText job[:job_dsl]
          xml.usingScriptText true
        else
          xml.targets job[:job_dsl_targets]
          xml.usingScriptText false
        end
        xml.ignoreExisting false
        xml.removedJobAction 'IGNORE'
      end
    end

    def out_dir
      'out/xml'
    end
  end
end
