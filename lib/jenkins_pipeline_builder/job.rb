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
      return local_output(xml) if JenkinsPipelineBuilder.debug || JenkinsPipelineBuilder.file_mode

      JenkinsPipelineBuilder.client.job.create_or_update(name, xml)
      [true, nil]
    end

    def to_xml
      raise 'Job name is not specified' unless name

      logger.info "Creating Yaml Job #{job}"
      job[:job_type] = 'free_style' unless job[:job_type]
      type = job[:job_type]
      return false, "Job type: #{type} is not one of #{job_methods.join(', ')}" unless known_type? type

      @xml = setup_freestyle_base(job)
      payload = send("update_#{type}")

      [true, payload]
    end

    private

    %i[free_style pull_request_generator].each do |method_name|
      define_method "update_#{method_name}" do
        @xml
      end
    end

    def known_type?(type)
      job_methods.include? type
    end

    def job_methods
      %w[job_dsl multi_project build_flow free_style pull_request_generator]
    end

    def local_output(xml)
      logger.info "Will create job #{job}"
      logger.info xml.to_s if @debug
      FileUtils.mkdir_p(out_dir) unless File.exist?(out_dir)
      File.open("#{out_dir}/#{name}.xml", 'w') { |f| f.write xml }
      [true, nil]
    end

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

    def update_multi_project
      n_xml = Nokogiri::XML(@xml)
      root = n_xml.root
      root.name = 'com.tikal.jenkins.plugins.multijob.MultiJobProject'
      n_xml.to_xml
    end

    def update_build_flow
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
        raise "Job template '#{template_name}' can't be resolved." unless @job_templates.key?(template_name)

        params.delete(:template)
        template = @job_templates[template_name]
        params = template.deep_merge(params)
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
