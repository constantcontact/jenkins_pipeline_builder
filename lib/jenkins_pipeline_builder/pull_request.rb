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

  class PullRequest
    attr_reader :project    # The root project YAML as a hash
    attr_reader :number     # The pull request number
    attr_reader :jobs       # The jobs in the pull request as an array of hashes
    attr_reader :generator  # The generator job YAML as a hash

    # Initialize
    def initialize(project, number, jobs, generator)
      # Set instance vars
      @project = Marshal.load(Marshal.dump(project))
      @number = number
      @jobs = Marshal.load(Marshal.dump(jobs))
      @generator = Marshal.load(Marshal.dump(generator))
      @project[:value][:pull_request_number] = "#{@number}"

      # Run
      run!
    end

    private

    # Apply all changes
    def run!
      git_version = JenkinsPipelineBuilder.registry.registry[:job][:scm_params].installed_version
      if git_version >= Gem::Version.new(2.0)
        @jobs.each_value do |j|
          j[:value][:scm_params] ||= {}
          j[:value][:scm_params][:changelog_to_branch] = { remote: 'origin', branch: 'pr-{{pull_request_number}}' }
        end
      end
      update_jobs!
      change_git!
      change_name!
    end

    # Change the git branch for each job
    def change_git!
      @jobs.each_value do |job|
        job[:value][:scm_branch] = "origin/pr/#{@number}/head"
        job[:value][:scm_params] = {} unless job[:value][:scm_params]
        job[:value][:scm_params][:refspec] = 'refs/pull/*:refs/remotes/origin/pr/*'
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
        @generator[:jobs].each do |gen|
          changes = gen[name.to_sym] if gen.is_a?(Hash) && gen.keys[0] == name.to_sym
        end
        # Apply changes
        Utils.hash_merge!(job[:value], changes) unless changes.nil?
      end
    end
  end
end
