module JenkinsPipelineBuilder
  class JobCollection
    attr_accessor :collection, :remote_dependencies
    attr_reader :loaded
    alias loaded? loaded

    def initialize
      @collection = {}
      @remote_dependencies = RemoteDependencies.new self
      @loaded = false
    end

    def clear_remote_dependencies
      @remote_dependencies = RemoteDependencies.new self
    end

    def logger
      JenkinsPipelineBuilder.logger
    end

    def standalone_jobs
      jobs.map { |job| { result: job } }
    end

    def projects
      collect_type :project
    end

    def jobs
      collect_type :job
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
      @loaded = true
    end

    private

    def collect_type(type_name)
      collection.values.select { |item| item if item[:type] == type_name }
    end

    def load_file(path, remote = false)
      hash = if path.end_with? 'json'
               JSON.parse(IO.read(path))
             else # elsif path.end_with?("yml") || path.end_with?("yaml")
               YAML.load_file(path)
             end
      logger.info "Loading file #{path}"
      hash.each do |section|
        load_section section, remote
      end
    rescue StandardError => e
      raise CustomErrors::ParseError.new e.message, path
    end

    def load_section(section, remote)
      Utils.symbolize_keys_deep!(section)
      key = section.keys.first
      value = section[key]
      if key == :dependencies
        logger.info 'Resolving Dependencies for remote project'
        remote_dependencies.load value
        return
      end

      unless value.is_a? Hash
        raise TypeError, %(Expected Hash received #{value.class}.
          Verify that the pipeline section is made up of a single {key: Hash/Object} pair
          See the definition for:
          \t#{section}).squeeze(' ')
      end

      name = value[:name]
      process_collection! name, key, value, remote
    end

    # TODO: This should be cleaned up a bit. I'm sure we can get rid of
    # the elsif and we should be more clear on the order of loading of things
    def process_collection!(name, key, value, remote)
      if collection.key?(name)
        existing_remote = collection[name.to_s][:remote]
        # skip if the existing item is local and the new item is remote
        return if remote && !existing_remote
        raise "Duplicate item with name '#{name}' was detected." unless existing_remote && !remote

        # override if the existing item is remote and the new is local
        logger.info "Duplicate item with name '#{name}' was detected from the remote folder."
      end
      collection[name.to_s] = { name: name.to_s, type: key, value: value, remote: remote }
    end

    def load_extensions(path)
      path = "#{path}/extensions"
      path = File.expand_path(path, Dir.getwd)
      return unless File.directory?(path)

      logger.info "Loading extensions from folder #{path}"
      logger.info Dir.glob("#{path}/*.rb").inspect
      Dir.glob("#{path}/**/*.rb").sort.each do |file|
        logger.info "Loaded #{file}"
        require file
      end
    end
  end
end
