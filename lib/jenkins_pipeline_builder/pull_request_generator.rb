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
    class NotFound < StandardError; end
    attr_accessor :open_prs, :application_name

    def initialize(application_name: nil, git_url: nil, git_org: nil, git_repo: nil)
      @application_name = application_name
      @open_prs = open_pull_requests git_url: git_url, git_org: git_org, git_repo: git_repo
    end

    def convert!(job_collection, pr)
      job_collection.defaults[:value][:application_name] = "#{application_name}-PR#{pr}"
      override = overrides pr
      job_collection.jobs.each { |j| j[:value].merge! override }
    end

    def delete_closed_prs
      jobs_to_delete = JenkinsPipelineBuilder.client.job.list "#{application_name}-PR.*"
      open_prs.each { |n| jobs_to_delete.reject! { |j| j.start_with? "#{application_name}-PR#{n}" } }
      jobs_to_delete.each { |j| JenkinsPipelineBuilder.client.job.delete j }
    end

    private

    def overrides(pr)
      git_version = JenkinsPipelineBuilder.registry.registry[:job][:scm_params].installed_version
      override = {
        scm_branch: "origin/pr/#{pr}/head",
        scm_params: {
          refspec: "refs/pull/#{pr}/head:refs/remotes/origin/pr/#{pr}/head"
        }
      }
      override[:scm_params][:changelog_to_branch] = {
        remote: 'origin', branch: "pr/#{pr}/head"
      } if git_version >= Gem::Version.new(2.0)
      override
    end

    def open_pull_requests(git_url: nil, git_org: nil, git_repo: nil)
      (git_url && git_org && git_repo) || fail('Please set github_site, git_org and git_repo_name in your project.')
      # Build the Git URL
      url = "#{git_url}/api/v3/repos/#{git_org}/#{git_repo}/pulls"
      # Download the JSON Data from the API
      resp = Net::HTTP.get_response(URI.parse(url))
      pulls = JSON.parse(resp.body)
      pulls.map { |p| p['number'] }
    end
  end
end
