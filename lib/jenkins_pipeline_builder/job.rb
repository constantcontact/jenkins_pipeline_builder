module JenkinsPipelineBuilder
  class Job
    attr_accessor :job

    def initialize(job)
      @job = job
    end

    def name
      job[:name]
    end

    def logger
      JenkinsPipelineBuilder.logger
    end

    def create_or_update
      success, payload = to_xml
      return success, payload unless success
      xml = payload
      if JenkinsPipelineBuilder.debug || JenkinsPipelineBuilder.file_mode
        logger.info "Will create job #{job}"
        logger.info "#{xml}" if @debug
        FileUtils.mkdir_p(out_dir) unless File.exist?(out_dir)
        File.open("#{out_dir}/#{name}.xml", 'w') { |f| f.write xml }
        return [true, nil]
      end

      if JenkinsPipelineBuilder.client.job.exists?(name)
        JenkinsPipelineBuilder.client.job.update(name, xml)
      else
        JenkinsPipelineBuilder.client.job.create(name, xml)
      end
      [true, nil]
    end

    def to_xml
      fail 'Job name is not specified' unless name

      logger.info "Creating Yaml Job #{job}"
      job[:job_type] = 'free_style' unless job[:job_type]
      case job[:job_type]
      when 'job_dsl'
        @xml = setup_freestyle_base(job)
        payload = update_job_dsl
      when 'multi_project'
        @xml = setup_freestyle_base(job)
        payload = adjust_multi_project
      when 'build_flow'
        @xml = setup_freestyle_base(job)
        payload = add_job_dsl
      when 'free_style', 'pull_request_generator'
        payload = setup_freestyle_base job
      else
        return false, "Job type: #{job[:job_type]} is not one of job_dsl, multi_project, build_flow or free_style"
      end

      [true, payload]
    end

    private

    def out_dir
      'out/xml'
    end

    def update_job_dsl
      n_xml = Nokogiri::XML(@xml)
      n_builders = n_xml.xpath('//builders').first
      Nokogiri::XML::Builder.with(n_builders) do |b_xml|
        build_job_dsl(job, b_xml)
      end
      n_xml.to_xml
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

    def adjust_multi_project
      n_xml = Nokogiri::XML(@xml)
      root = n_xml.root
      root.name = 'com.tikal.jenkins.plugins.multijob.MultiJobProject'
      n_xml.to_xml
    end

    def add_job_dsl
      n_xml = Nokogiri::XML(@xml)
      n_xml.root.name = 'com.cloudbees.plugins.flow.BuildFlow'
      Nokogiri::XML::Builder.with(n_xml.root) do |b_xml|
        b_xml.dsl job[:build_flow]
      end
      n_xml.to_xml
    end

    def setup_freestyle_base(params)
      # I'm pretty unclear what these templates are...
      if params.key?(:template)
        template_name = params[:template]
        fail "Job template '#{template_name}' can't be resolved." unless @job_templates.key?(template_name)
        params.delete(:template)
        template = @job_templates[template_name]
        puts "Template found: #{template}"
        params = template.deep_merge(params)
        puts "Template merged: #{template}"
      end

      xml = JenkinsPipelineBuilder.client.job.build_freestyle_config(params)
      n_xml = Nokogiri::XML(xml, &:noblanks)

      logger.debug 'Loading the required modules'
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, n_xml)
      logger.debug 'Module loading complete'

      n_xml.to_xml
    end
  end
end
