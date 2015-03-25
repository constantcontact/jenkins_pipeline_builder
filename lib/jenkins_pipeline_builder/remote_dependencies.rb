module JenkinsPipelineBuilder
  class RemoteDependencies
    attr_reader :job_collection, :entries

    def initialize(job_collection)
      @entries = {}
      @job_collection = job_collection
    end

    def logger
      JenkinsPipelineBuilder.logger
    end

    def cleanup
      entries.each_value do |file|
        FileUtils.rm_r file
        FileUtils.rm_r "#{file}.tar"
      end
    end

    # TODO: Look into remote jobs not working according to sinan

    def load(dependencies)
      ### Load remote YAML
      # Download Tar.gz
      dependencies.each do |source|
        source = source[:source]
        url = source[:url]

        file = "remote-#{entries.length}"
        if entries[url]
          file = entries[url]
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
          return job_collection.load_from_path(path, true)
        end

        load_templates(path, source[:templates])
      end
    end

    private

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
        job_collection.load_from_path(path, true)
        true
      else
        false
      end
    end

    def download_yaml(url, file, remote_opts = {})
      entries[url] = file
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
  end
end
