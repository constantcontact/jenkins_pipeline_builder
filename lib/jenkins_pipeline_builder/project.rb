module JenkinsPipelineBuilder
  class Project
    attr_reader :input
    attr_accessor :errors
    def initialize(name, input)
      @name = name
      @input = input
      @errors = {}
    end

    def publish
      success, payload = resolve_project(input)
      return { project_name: 'Failed to resolve' } unless success

      logger.info 'successfully resolved project'
      compiled_project = payload

      self.errors = publish_jobs(compiled_project[:value][:jobs]) if compiled_project[:value][:jobs]
      return unless compiled_project[:value][:views]
      compiled_project[:value][:views].each do |v|
        compiled_view = v[:result]
        view.create(compiled_view)
      end
    end
  end
end
