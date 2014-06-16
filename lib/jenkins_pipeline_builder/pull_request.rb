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

module JenkinsPipelineBuilder
  class PullRequestGenerator
    # Initializes a new View object.
    #
    # @param generator [Generator] the client object
    #
    # @return [View] the view object
    #
    def initialize(generator)
      @generator = generator
      @client = generator.client
      @logger = @client.logger
    end
    
    # Check for Github Pull Requests
    #
    # args[:git_url] URL to the github main page ex. https://www.github.com/
    # args[:git_repo] Name of repo only, not url  ex. jenkins_pipeline_builder
    # args[:git_org] The Orig user ex. igorshare
    # @return = array of pull request numbers
    def check_for_pull(args)
      raise "Please specify all arguments" unless args[:git_url] && args[:git_org] && args[:git_repo]
      # Build the Git URL
      git_url = "#{args[:git_url]}api/v3/repos/#{args[:git_org]}/#{args[:git_repo]}/pulls"
      
      # Download the JSON Data from the API
      resp = Net::HTTP.get_response(URI.parse(git_url))
      pulls = JSON.parse(resp.body)
      pulls.map{ |p| p["number"]}
    end

    # Purge old builds
    def purge_old(pull_requests, project)
      @logger.info "Current pull requests: #{pull_requests}"
      # Read File
      old_requests = File.new('pull_requests.csv', 'a+').read.split(',')
      
      # Pop off current pull requests
      old_requests.delete_if { |req| pull_requests.include?(req.to_i)}

      # Delete the old requests from jenkins
      old_requests.map! { |pr| "#{project[:name]}-PR#{pr}" }
      @logger.info "Purging old requests: #{old_requests}"
      old_requests.each do |req|
        jobs = @client.job.list "#{req}.*"
        jobs.each do |job|
          @client.job.delete job
        end
      end
      # Write File
      File.open('pull_requests.csv', 'w+') { |file| file.write pull_requests.join(",")}
    end

    def run(project, job_collection, generator_job)
      @logger.info "Begin running Pull Request Generator"
      git_args = {}
      pull_requests = check_for_pull generator_job[:value]
      purge_old(pull_requests, project)
      main_collection = job_collection
      pull_requests.each do |number|
        # Manipulate the YAML
        req = JenkinsPipelineBuilder::PullRequest.new(project, number, main_collection, generator_job)
        @generator.job_collection.merge req.jobs
        project = req.project

        # Overwrite the jobs from the generator to the project
        project[:value][:jobs] = generator_job[:value][:jobs]
        
        # Build the jobs
        success, compiled_project = @generator.resolve_project(project)
        compiled_project[:value][:jobs].each do |i|
          job = i[:result]
          success, payload = @generator.compile_job_to_xml(job)
          if success
            @generator.create_or_update(job, payload)
          end
        end
      end
    end
  end
  class PullRequest

    # Accessors
    attr_reader :project    # The root project YAML as a hash
    attr_reader :number     # The pull request number
    attr_reader :jobs       # The jobs in the pull request as an array of hashes
    attr_reader :generator  # The generator job YAML as a hash

    # Initialize
    def initialize(project, number, jobs, generator)
        # Set instance vars
        @project = project.clone 
        @number = number
        @jobs = jobs.clone
        @generator = generator.clone
        
        # Run
        run!
    end

    private

    # Apply all changes
    def run!
        update_jobs!
        change_git!
    end

    # Change the git branch for each job
    def change_git!
        @jobs.each_value do |job|
            job[:value][:scm_branch] = "origin/pr/#{@number}/head"
            job[:value][:scm_refspec] = "refs/pull/*:refs/remotes/origin/pr/*"
        end
    end

    # Change the name of the pull request project
    def change_name!
        @project[:name] = "#{@project[:name]}-PR#{@number}" if @project[:name]
        @project[:value][:name] = "#{@project[:value][:name]}-PR#{@number}" if @project[:value][:name]
    end

    # Apply any specified changes to each job
    def update_jobs!
        @jobs.each_value do |job|
              name = job[:name]
              changes = nil
              # Search the generator for changes
              @generator[:value][:jobs].each do |gen|
                if gen.is_a? Hash
                  if gen.keys[0] == name.to_sym
                    changes = gen[name.to_sym]
                  end
                end
              end
              # Apply changes
              if changes != nil
                  apply_changes!(job[:value], changes)
              end
        end
    end

    # Apply changes to a single job
    def apply_changes!(original, changes)
      # Apply the specified changes
      changes.each do |cK, cV|
        # The change doesn't already exist in the original
        unless original.include? cK
          original[cK] = cV
          # The change does exists, so we need to replace!
        else
          # Loop through the original job
          original.each do |oK, oV|
            if oK == cK
              # The change is a hash
              if cV.is_a? Hash and oV.is_a? Hash
                apply_changes!(oV, cV)
                # The change is an array
              elsif cV.is_a? Array and oV.is_a? Array 
                # Add changes
                # cV.each do |elem|
                #     unless oV.include? elem
                #         original[oK].push elem
                #     end
                # end
                # Replace entire array
                original[oK] = cV
                # The change is a string, etc
              else 
                original[oK] = cV
              end
            end
          end
        end
      end
    end
  end # class
end # module
