#
# Copyright (c) 2014 Constant Contact
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
    attr_reader :purge
    attr_reader :create
    attr_reader :jobs

    def initialize(project, jobs, pull_job)
      @purge = []
      @create = []
      @jobs = {}

      pull_requests = check_for_pull pull_job
      purge_old(pull_requests, project)
      pull_requests.each do |number|
        # Manipulate the YAML
        req = JenkinsPipelineBuilder::PullRequest.new(project, number, jobs, pull_job)
        @jobs.merge! req.jobs
        project_new = req.project

        # Overwrite the jobs from the generator to the project
        project_new[:value][:jobs] = req.jobs.keys
        @create << project_new
      end
    end

    private

    # Check for Github Pull Requests
    #
    # args[:git_url] URL to the github main page ex. https://www.github.com/
    # args[:git_repo] Name of repo only, not url  ex. jenkins_pipeline_builder
    # args[:git_org] The Orig user ex. constantcontact
    # @return = array of pull request numbers
    def check_for_pull(args)
      fail 'Please specify all arguments' unless args[:git_url] && args[:git_org] && args[:git_repo]
      # Build the Git URL
      git_url = "#{args[:git_url]}api/v3/repos/#{args[:git_org]}/#{args[:git_repo]}/pulls"

      # Download the JSON Data from the API
      resp = Net::HTTP.get_response(URI.parse(git_url))
      pulls = JSON.parse(resp.body)
      pulls.map { |p| p['number'] }
    end

    # Purge old builds
    def purge_old(pull_requests, project)
      reqs = pull_requests.clone.map { |req| "#{project[:name]}-PR#{req}" }
      # Read File
      old_requests = File.new('pull_requests.csv', 'a+').read.split(',')

      # Pop off current pull requests
      old_requests.delete_if { |req| reqs.include?("#{req}") }
      @purge = old_requests

      # Write File
      File.open('pull_requests.csv', 'w+') { |file| file.write reqs.join(',') }
    end
  end
end
