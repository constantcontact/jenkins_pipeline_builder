#
# Copyright (c) 2014 Igor Moochnick
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
require 'pp'

module JenkinsPipelineBuilder
  class Generator
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
    def initialize(client)
      @client        = client
      @logger        = @client.logger
      #@logger.level = (@debug) ? Logger::DEBUG : Logger::INFO;
      @job_templates = {}
      @job_collection = {}
      @extensions = {}
      @remote_depends = {}

      @module_registry = ModuleRegistry.new(
        job: {
          description: JobBuilder.method(:change_description),
          scm_params: JobBuilder.method(:apply_scm_params),
          hipchat: JobBuilder.method(:hipchat_notifier),
          parameters: JobBuilder.method(:build_parameters),
          priority: JobBuilder.method(:use_specific_priority),
          discard_old: JobBuilder.method(:discard_old_param),
          throttle: JobBuilder.method(:throttle_job),
          prepare_environment: JobBuilder.method(:prepare_environment),
          concurrent_build: JobBuilder.method(:concurrent_build),
          builders: {
            registry: {
              multi_job: Builders.method(:build_multijob),
              inject_vars_file: Builders.method(:build_environment_vars_injector),
              shell_command: Builders.method(:build_shell_command),
              maven3: Builders.method(:build_maven3),
              blocking_downstream: Builders.method(:blocking_downstream),
              remote_job: Builders.method(:start_remote_job)
            },
            method:
            lambda { |registry, params, n_xml| @module_registry.run_registry_on_path('//builders', registry, params, n_xml) }
          },
          publishers: {
            registry: {
              git: Publishers.method(:push_to_git),
              hipchat: Publishers.method(:push_to_hipchat),
              description_setter: Publishers.method(:description_setter),
              downstream: Publishers.method(:push_to_projects),
              junit_result: Publishers.method(:publish_junit),
              coverage_result: Publishers.method(:publish_rcov),
              post_build_script: Publishers.method(:post_build_script),
              groovy_postbuild: Publishers.method(:groovy_postbuild)
            },
            method:
            lambda { |registry, params, n_xml| @module_registry.run_registry_on_path('//publishers', registry, params, n_xml) }
          },
          wrappers: {
            registry: {
              timestamp: Wrappers.method(:console_timestamp),
              ansicolor: Wrappers.method(:ansicolor),
              artifactory: Wrappers.method(:publish_to_artifactory),
              rvm: Wrappers.method(:run_with_rvm),
              rvm05: Wrappers.method(:run_with_rvm05),
              inject_env_var: Wrappers.method(:inject_env_vars),
              inject_passwords: Wrappers.method(:inject_passwords),
              maven3artifactory: Wrappers.method(:artifactory_maven3_configurator)
            },
            method:
            lambda { |registry, params, n_xml| @module_registry.run_registry_on_path('//buildWrappers', registry, params, n_xml) }
          },
          triggers: {
            registry: {
              git_push: Triggers.method(:enable_git_push),
              scm_polling: Triggers.method(:enable_scm_polling),
              periodic_build: Triggers.method(:enable_periodic_build),
              upstream: Triggers.method(:enable_upstream_check)
            },
            method:
            lambda { |registry, params, n_xml| @module_registry.run_registry_on_path('//triggers', registry, params, n_xml) }
          }
        }
      )
    end

    def load_extensions(path)
      path = "#{path}/extensions"
      path = File.expand_path(path, Dir.getwd)
      if File.directory?(path)
        @logger.info "Loading extensions from folder #{path}"
        Dir[File.join(path, '/*.yaml'), File.join(path, '/*.yml')].each do |file|
          @logger.info "Loading file #{file}"
          yaml = YAML.load_file(file)
          yaml.each do |ext|
            Utils.symbolize_keys_deep!(ext)
            ext = ext[:extension]
            name = ext[:name]
            type = ext[:type]
            function = ext[:function]
            raise "Duplicate extension with name '#{name}' was detected." if @extensions.has_key?(name)
            @extensions[name.to_s] = { name: name.to_s, type: type, function: function }
          end
        end
      end
      @extensions.each_value do |ext|
        name = ext[:name].to_sym
        registry = @module_registry.registry[:job]
        function = eval "Proc.new {|params,xml| #{ext[:function]} }"
        type = ext[:type].downcase.pluralize.to_sym if ext[:type]
        if type
          registry[type][:registry][name] = function
        else
          registry[name] = function
        end
      end
    end

    def debug=(value)
      @debug = value
      @logger.level = (value) ? Logger::DEBUG : Logger::INFO
    end

    attr_reader :debug
    attr_accessor :client
    attr_accessor :no_files
    attr_accessor :job_collection

    # Creates an instance to the View class by passing a reference to self
    #
    # @return [JenkinsApi::Client::System] An object to System subclass
    #
    def view
      JenkinsPipelineBuilder::View.new(self)
    end

    def load_collection_from_path(path, recursively = false, remote=false)
      path = File.expand_path(path, Dir.getwd)
      if File.directory?(path)
        @logger.info "Generating from folder #{path}"
        Dir[File.join(path, '/*.yaml'), File.join(path, '/*.yml')].each do |file|
          if File.directory?(file) # TODO: This doesn't work unless the folder contains .yml or .yaml at the end
            if recursively
              load_collection_from_path(File.join(path, file), recursively)
            else
              next
            end
          end
          @logger.info "Loading file #{file}"
          yaml = YAML.load_file(file)
          load_job_collection(yaml, remote)
        end
      else
        @logger.info "Loading file #{path}"
        yaml = YAML.load_file(path)
        load_job_collection(yaml, remote)
      end
    end

    def load_job_collection(yaml, remote=false)
      yaml.each do |section|
        Utils.symbolize_keys_deep!(section)
        key = section.keys.first
        value = section[key]
        if key == :dependencies
          @logger.info 'Resolving Dependencies for remote project'
          return load_remote_yaml(value)
        end

        name = value[:name]
        if @job_collection.has_key?(name)
          if remote
            @logger.info "Duplicate item with name '#{name}' was detected from the remote folder."
          else
            raise "Duplicate item with name '#{name}' was detected."
          end
        else
          @job_collection[name.to_s] = { name: name.to_s, type: key, value: value }
        end
      end
    end

    def get_item(name)
      @job_collection[name.to_s]
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
          highest = '0' # Default to v1
          folders.each do |f|
            highest = f if f > highest # Note: to_i returns any integers in the folder name
          end
          template[:version] = highest unless highest == 0
        end
        path = File.join(path, template[:version]) unless template[:version].nil?
        path = File.join(path, 'pipeline')
      end

      if File.directory?(path)
        @logger.info "Loading from #{path}"
        load_collection_from_path(path, false, true)
        true
      else
        false
      end
    end

    def download_yaml(url, file)
      @remote_depends[url] = file
      @logger.info "Downloading #{url} to #{file}.tar"
      open("#{file}.tar", 'w') do |local_file|
        open(url) do |remote_file|
          local_file.write(Zlib::GzipReader.new(remote_file).read)
        end
      end

      # Extract Tar.gz to 'remote' folder
      @logger.info "Unpacking #{file}.tar to #{file} folder"
      Archive::Tar::Minitar.unpack("#{file}.tar", file)
    end

    def load_remote_yaml(dependencies)
      ### Load remote YAML
      # Download Tar.gz
      dependencies.each do |source|
        source = source[:source]
        url = source[:url]
        file = "remote-#{@remote_depends.length}"
        if @remote_depends[url]
          file = @remote_depends[url]
        else
          download_yaml(url, file)
        end

        path = File.expand_path(file, Dir.getwd)
        # Load templates recursively
        unless source[:templates]
          @logger.info 'No specific template specified'
          # Try to load the folder or the pipeline folder
          path = File.join(path, 'pipeline') if Dir.entries(path).include? 'pipeline'
          return load_collection_from_path(path)
        end

        load_templates(source[:templates])
      end
    end

    def load_templates(templates)
      templates.each do |template|
        version = template[:version] || 'newest'
        @logger.info "Loading #{template[:name]} at version #{version}"
        # Move into the remote folder and look for the template folder
        remote = Dir.entries(path)
        if remote.include? template[:name]
          # We found the template name, load this path
          @logger.info 'We found the template!'
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

    def prepare_jobs(jobs)
      jobs.map! do |job|
        job.kind_of?(String) ? { job.to_sym => {} } : job
      end
    end

    def process_job_changes(jobs)
      jobs.each do |job|
        job_id = job.keys.first
        j = get_item(job_id)
        Utils.hash_merge!(j, job[job_id])
        j[:value][:name] = j[:job_name] if j[:job_name]
      end
    end

    def process_views(views, project, errors={})
      views.map! do |view|
        view.kind_of?(String) ? { view.to_sym => {} } : view
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

    def process_jobs(jobs, project, errors={})
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
      defaults = get_item('global')
      settings = defaults.nil? ? {} : defaults[:value] || {}

      project[:settings] = Compiler.get_settings_bag(project, settings) unless project[:settings]
      project_body = project[:value]

      jobs = prepare_jobs(project_body[:jobs]) if project_body[:jobs]
      @logger.info project
      process_job_changes(jobs)
      errors = process_jobs(jobs, project)
      errors = process_view(project_body[:views], project,  errors) if project_body[:views]

      errors.each do |k,v|
        puts "Encountered errors processing: #{k}:"
        v.each do |key, error|
          puts "  key: #{key} had the following error:"
          puts "  #{error.inspect}"
        end
      end
      return false, 'Encountered errors exiting' unless errors.empty?

      return true, project
    end

    def resolve_job_by_name(name, settings = {})
      job = get_item(name)
      raise "Failed to locate job by name '#{name}'" if job.nil?
      job_value = job[:value]
      @logger.debug "Compiling job #{name}"
      success, payload = Compiler.compile(job_value, settings, @job_collection)
      return success, payload
    end

    def projects
      result = []
      @job_collection.values.each do |item|
        result << item if item[:type] == :project
      end
      return result
    end

    def jobs
      result = []
      @job_collection.values.each do |item|
        result << item if item[:type] == :job
      end
      return result
    end

    def publish_project(project_name, errors={})
      projects.each do |project|
        next if project_name && project[:name] == project_name
        success, payload = resolve_project(project)
        if success
          puts 'successfully resolved project'
          compiled_project = payload
        else
          puts payload
          return false
        end

        if compiled_project[:value][:jobs]
          errors = publish_jobs(compiled_project[:value][:jobs])
        end
        if compiled_project[:value][:views]
          compiled_project[:value][:views].each do |v|
            compiled_view = v[:result]
            view.create(compiled_view)
          end
        end
      end
      errors
    end

    def publish_jobs(jobs, errors = {})
      jobs.each do |i|
        puts "Processing #{i}"
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
    def bootstrap(path, project_name)
      @logger.info "Bootstrapping pipeline from path #{path}"
      load_collection_from_path(path)
      cleanup_temp_remote
      load_extensions(path)
      errors = {}
      # Publish all the jobs if the projects are not found
      if projects.count == 0
        errors = publish_jobs(jobs)
      else
        errors = publish_project(project_name)
      end
      errors.each do |k,v|
        @logger.error "Encountered errors compiling: #{k}:"
        @logger.error v
      end
    end

    def pull_request(path, project_name)
      @logger.info "Pull Request Generator Running from path #{path}"
      load_collection_from_path(path)
      cleanup_temp_remote
      load_extensions(path)
      jobs = {}
      projects.each do |project|
        if project[:name] == project_name || project_name == nil
          project_body = project[:value]
          project_jobs = project_body[:jobs] || []
          @logger.info "Using Project #{project}"
          pull_job = nil
          project_jobs.each do |job|
            job = @job_collection[job.to_s]
            pull_job = job if job[:value][:job_type] == 'pull_request_generator'
          end
          raise 'No Pull Request Found for Project' unless pull_job
          pull_jobs = pull_job[:value][:jobs] || []
          pull_jobs.each do |job|
            if job.is_a? String
              jobs[job.to_s] = @job_collection[job.to_s]
            else
              jobs[job.keys[0].to_s] = @job_collection[job.keys[0].to_s]
            end
          end
          pull = JenkinsPipelineBuilder::PullRequestGenerator.new(self)
          pull.run(project, jobs, pull_job)
        end
      end
    end

    def dump(job_name)
      @logger.info "Debug #{@debug}"
      @logger.info "Dumping #{job_name} into #{job_name}.xml"
      xml = @client.job.get_config(job_name)
      File.open(job_name + '.xml', 'w') { |f| f.write xml }
    end

    def create_or_update(job, xml)
      job_name = job[:name]
      if @debug
        @logger.info "Will create job #{job}"
        @logger.info "#{xml}"
        File.open(job_name + '.xml', 'w') { |f| f.write xml }
        return
      end

      if @client.job.exists?(job_name)
        @client.job.update(job_name, xml)
      else
        @client.job.create(job_name, xml)
      end
    end

    def compile_job_to_xml(job)
      raise 'Job name is not specified' unless job[:name]

      @logger.info "Creating Yaml Job #{job}"
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

      return true, payload
    end

    def adjust_multi_project(xml)
      n_xml = Nokogiri::XML(xml)
      root = n_xml.root()
      root.name = 'com.tikal.jenkins.plugins.multijob.MultiJobProject'
      n_xml.to_xml
    end

    def compile_freestyle_job_to_xml(params)
      if params.has_key?(:template)
        template_name = params[:template]
        raise "Job template '#{template_name}' can't be resolved." unless @job_templates.has_key?(template_name)
        params.delete(:template)
        template = @job_templates[template_name]
        puts "Template found: #{template}"
        params = template.deep_merge(params)
        puts "Template merged: #{template}"
      end

      xml   = @client.job.build_freestyle_config(params)
      n_xml = Nokogiri::XML(xml)

      @module_registry.traverse_registry_path('job', params, n_xml)

      n_xml.to_xml
    end

    def add_job_dsl(job, xml)
      n_xml = Nokogiri::XML(xml)
      n_xml.root.name = 'com.cloudbees.plugins.flow.BuildFlow'
      Nokogiri::XML::Builder.with(n_xml.root) do |xml|
        xml.dsl job[:build_flow]
      end
      n_xml.to_xml
    end

    # TODO: make sure this is tested
    def update_job_dsl(job, xml)
      n_xml      = Nokogiri::XML(xml)
      n_builders = n_xml.xpath('//builders').first
      Nokogiri::XML::Builder.with(n_builders) do |xml|
        build_job_dsl(job, xml)
      end
      n_xml.to_xml
    end

    def generate_job_dsl_body(params)
      @logger.info 'Generating pipeline'

      xml = @client.job.build_freestyle_config(params)

      n_xml = Nokogiri::XML(xml)
      if n_xml.xpath('//javaposse.jobdsl.plugin.ExecuteDslScripts').empty?
        p_xml = Nokogiri::XML::Builder.new(encoding:  'UTF-8') do |b_xml|
          build_job_dsl(params, b_xml)
        end

        n_xml.xpath('//builders').first.add_child("\r\n" + p_xml.doc.root.to_xml(indent:  4) + "\r\n")
        xml = n_xml.to_xml
      end
      xml
    end

    def build_job_dsl(job, xml)
      xml.send('javaposse.jobdsl.plugin.ExecuteDslScripts') do
        if job.has_key?(:job_dsl)
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
  end
end
