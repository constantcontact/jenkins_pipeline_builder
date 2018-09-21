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

    def load(dependencies)
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
        return load_default_path path unless source[:templates]

        load_templates(path, source[:templates])
      end
    end

    private

    def load_default_path(path)
      logger.info 'No specific template specified'
      path = File.join(path, 'pipeline') if Dir.entries(path).include? 'pipeline'
      job_collection.load_from_path(path, true)
    end

    def load_template(path, template)
      # If we specify what folder the yaml is in, load that
      path = template_path path, template

      if File.directory?(path)
        logger.info "Loading from #{path}"
        job_collection.load_from_path(path, true)
        true
      else
        false
      end
    end

    def highest_template_version(path)
      folders = Dir.entries(path)
      highest = folders.max
      highest = highest unless highest == 0
      highest
    end

    def use_newest_version?(template, path)
      (template[:version].nil? || template[:version] == 'newest') && File.directory?(path)
    end

    def template_path(path, template)
      if template[:folder]
        path = File.join(path, template[:folder])
      else
        path = File.join(path, template[:name]) unless template[:name] == 'default'
        # If we are looking for the newest version or no version was set
        template[:version] = highest_template_version path if use_newest_version? template, path
        path = File.join(path, template[:version]) unless template[:version].nil?
        path = File.join(path, 'pipeline')
      end

      path
    end

    def download_yaml(url, file, remote_opts = {})
      entries[url] = file
      logger.info "Downloading #{url} to #{file}.tar"
      File.open("#{file}.tar", 'w') do |local_file|
        URI.parse(url).open(remote_opts) do |remote_file|
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
