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
      old_requests = File.new('pull_requests.csv', 'r').read.split(',')
      
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
      pull_requests.each do |number|
        req = JenkinsPipelineBuilder::PullRequest.new(project, number, job_collection, generator_job)
        @generator.job_collection = req.job_collection
        t_project = req.project
        project[:value][:jobs] = generator_job[:value][:jobs]
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

  end
end