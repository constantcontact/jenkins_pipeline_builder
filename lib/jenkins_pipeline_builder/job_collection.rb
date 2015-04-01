module JenkinsPipelineBuilder
  class JobCollection
    attr_accessor :collection, :remote_dependencies

    def initialize
      @collection = {}
      @remote_dependencies = RemoteDependencies.new self
    end

    def clear_remote_dependencies
      @remote_dependencies = RemoteDependencies.new self
    end

    def logger
      JenkinsPipelineBuilder.logger
    end

    def projects
      result = []
      collection.values.each do |item|
        result << item if item[:type] == :project
      end
      result
    end

    def standalone_jobs
      jobs.map { |job| { result: job } }
    end

    def jobs
      result = []
      collection.values.each do |item|
        result << item if item[:type] == :job
      end
      result
    end

    def defaults
      collection.each_value do |item|
        return item if item[:type] == 'defaults' || item[:type] == :defaults
      end
      # This is here for historical purposes
      get_item('global')
    end

    def get_item(name)
      collection[name.to_s]
    end

    def load_from_path(path, remote = false)
      load_extensions(path)
      path = File.expand_path(path, Dir.getwd)
      if File.directory?(path)
        logger.info "Generating from folder #{path}"
        Dir[File.join(path, '/*.{yaml,yml}')].each do |file|
          load_file(file, remote)
        end
        Dir[File.join(path, '/*.json')].each do |file|
          load_file(file, remote)
        end
      else
        load_file(path, remote)
      end
      remote_dependencies.cleanup if remote
    end

    private

    def load_file(path, remote = false)
      if path.end_with? 'json'
        hash = JSON.parse(IO.read(path))
      else  # elsif path.end_with?("yml") || path.end_with?("yaml")
        hash = YAML.load_file(path)
      end
      logger.info "Loading file #{path}"
      hash.each do |section|
        Utils.symbolize_keys_deep!(section)
        key = section.keys.first
        value = section[key]
        if key == :dependencies
          logger.info 'Resolving Dependencies for remote project'
          remote_dependencies.load value
          next
        end
        name = value[:name]
        if collection.key?(name)
          existing_remote = collection[name.to_s][:remote]
          # skip if the existing item is local and the new item is remote
          if remote && !existing_remote
            next
          # override if the existing item is remote and the new is local
          elsif existing_remote && !remote
            logger.info "Duplicate item with name '#{name}' was detected from the remote folder."
          else
            fail "Duplicate item with name '#{name}' was detected."
          end
        end
        collection[name.to_s] = { name: name.to_s, type: key, value: value, remote: remote }
      end
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
  end
end
