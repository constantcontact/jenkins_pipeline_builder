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
    def initialize(args, client)
      @client        = client
      @logger        = @client.logger
      #@logger.level = (@debug) ? Logger::DEBUG : Logger::INFO;
      @job_templates = {}
      @job_collection = {}

      @module_registry = ModuleRegistry.new ({
          job: {
              description: JobBuilder.method(:change_description),
              scm_params: JobBuilder.method(:apply_scm_params),
              hipchat: JobBuilder.method(:hipchat_notifier),
              parameters: JobBuilder.method(:build_parameters),
              builders: {
                  registry: {
                      multi_job: Builders.method(:build_multijob),
                      inject_vars_file: Builders.method(:build_environment_vars_injector),
                      shell_command: Builders.method(:build_shell_command),
                      maven3: Builders.method(:build_maven3)
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
                      post_build_script: Publishers.method(:post_build_script)
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
                      periodic_build: Triggers.method(:enable_periodic_build)
                  }, 
                  method:
                    lambda { |registry, params, n_xml| @module_registry.run_registry_on_path('//triggers', registry, params, n_xml) }
              }
          }
      })
    end

    attr_accessor :client
    def debug=(value)
      @debug = value
      @logger.level = (value) ? Logger::DEBUG : Logger::INFO;
    end
    def debug
      @debug
    end
    # TODO: WTF?
    attr_accessor :no_files
    attr_accessor :job_collection

    # Creates an instance to the View class by passing a reference to self
    #
    # @return [JenkinsApi::Client::System] An object to System subclass
    #
    def view
      JenkinsPipelineBuilder::View.new(self)
    end

    def load_collection_from_path(path, recursively = false)
      path = File.expand_path(path, relative_to=Dir.getwd)
      if File.directory?(path)
        @logger.info "Generating from folder #{path}"
        Dir[File.join(path, '/*.yaml'), File.join(path, '/*.yml')].each do |file|
          if File.directory?(file)
            if recursively
              load_collection_from_path(File.join(path, file), recursively)
            else
              next
            end
          end
          @logger.info "Loading file #{file}"
          yaml = YAML.load_file(file)
          load_job_collection(yaml)
        end
      else
        @logger.info "Loading file #{path}"
        yaml = YAML.load_file(path)
        load_job_collection(yaml)
      end
    end

    def load_job_collection(yaml)
      yaml.each do |section|
        Utils.symbolize_keys_deep!(section)
        key = section.keys.first
        value = section[key]
        name = value[:name]
        raise "Duplicate item with name '#{name}' was detected." if @job_collection.has_key?(name)
        @job_collection[name.to_s] = { name: name.to_s, type: key, value: value }
      end
    end

    def get_item(name)
      @job_collection[name.to_s]
    end

    def resolve_project(project)
      defaults = get_item('global')
      settings = defaults.nil? ? {} : defaults[:value] || {}

      project[:settings] = Compiler.get_settings_bag(project, settings) unless project[:settings]
      project_body = project[:value]

      # Process jobs
      jobs = project_body[:jobs] || []
      jobs.map! do |job|
        job.kind_of?(String) ? { job.to_sym => {} } : job
      end
      errors = {}
      @logger.info project
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

      # Process views
      views = project_body[:views] || []
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

      errors.each do |k,v|
        puts "Encountered errors processing: #{k}:"
        v.each do |key, error|
          puts "  key: #{key} had the following error:"
          puts "  #{error.inspect}"
        end
      end
      return false, "Encountered errors exiting" unless errors.empty?

      return true, project
    end

    def resolve_job_by_name(name, settings = {})
      job = get_item(name)
      raise "Failed to locate job by name '#{name}'" if job.nil?
      job_value = job[:value]
      @logger.debug "Compiling job #{name}"

      success, payload = Compiler.compile(job_value, settings)
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

    def bootstrap(path)
      @logger.info "Bootstrapping pipeline from path #{path}"
      load_collection_from_path(path)

      errors = {}
      # Publish all the jobs if the projects are not found
      if projects.count == 0
        jobs.each do |i|
          job = i[:value]
          success, payload = compile_job_to_xml(job)
          if success
            create_or_update(job, payload)
          else
            errors[job[:name]] = payload
          end
        end
      else
        projects.each do |project|
          success, payload = resolve_project(project)
          if success
            puts 'successfully resolved project'
            compiled_project = payload
          else
            puts payload
            return false
          end

          if compiled_project[:value][:jobs]
            compiled_project[:value][:jobs].each do |i|
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
          end

          if compiled_project[:value][:views]
            compiled_project[:value][:views].each do |v|
              _view = v[:result]
              view.create(_view)
            end
          end
        end
      end
      errors.each do |k,v|
        @logger.error "Encountered errors compiling: #{k}:"
        @logger.error v
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
        when 'free_style'
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
      n_xml      = Nokogiri::XML(xml)
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
      @logger.info "Generating pipeline"

      xml = @client.job.build_freestyle_config(params)

      n_xml = Nokogiri::XML(xml)
      if n_xml.xpath('//javaposse.jobdsl.plugin.ExecuteDslScripts').empty?
        p_xml = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |b_xml|
          build_job_dsl(params, b_xml)
        end

        n_xml.xpath('//builders').first.add_child("\r\n" + p_xml.doc.root.to_xml(:indent => 4) + "\r\n")
        xml = n_xml.to_xml
      end
      xml
    end

    def build_job_dsl(job, xml)
      xml.send('javaposse.jobdsl.plugin.ExecuteDslScripts') {
        if job.has_key?(:job_dsl)
          xml.scriptText job[:job_dsl]
          xml.usingScriptText true
        else
          xml.targets job[:job_dsl_targets]
          xml.usingScriptText false
        end
        xml.ignoreExisting false
        xml.removedJobAction 'IGNORE'
      }
    end
  end
end
