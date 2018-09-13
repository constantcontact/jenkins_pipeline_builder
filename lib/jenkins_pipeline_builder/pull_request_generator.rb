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

    def initialize(defaults = {})
      @application_name = defaults[:application_name] || raise('Please set "application_name" in your project!')
      @open_prs = active_prs defaults[:github_site], defaults[:git_org], defaults[:git_repo_name]
    end

    def convert!(job_collection, pr_number)
      job_collection.defaults[:value][:application_name] = "#{application_name}-PR#{pr_number}"
      job_collection.defaults[:value][:pull_request_number] = pr_number.to_s
      job_collection.jobs.each { |j| override j[:value], pr_number }
    end

    def delete_closed_prs
      return if JenkinsPipelineBuilder.debug

      jobs_to_delete = JenkinsPipelineBuilder.client.job.list "^#{application_name}-PR(\\d+)-(.*)$"
      open_prs.each do |pr|
        jobs_to_delete.reject! { |j| j.start_with? "#{application_name}-PR#{pr[:number]}" }
      end
      jobs_to_delete.each { |j| JenkinsPipelineBuilder.client.job.delete j }
    end

    private

    def override(job, pr_number)
      git_version = JenkinsPipelineBuilder.registry.registry[:job][:scm_params].installed_version
      job[:scm_branch] = "origin/pr/#{pr_number}/head"
      job[:scm_params] ||= {}
      job[:scm_params][:refspec] = "refs/pull/#{pr_number}/head:refs/remotes/origin/pr/#{pr_number}/head"
      job[:scm_params][:changelog_to_branch] ||= {}
      if Gem::Version.new(2.0) < git_version
        job[:scm_params][:changelog_to_branch]
          .merge!(remote: 'origin', branch: "pr/#{pr_number}/head")
      end
    end

    def active_prs(git_url, git_org, git_repo)
      (git_url && git_org && git_repo) || raise('Please set github_site, git_org and git_repo_name in your project.')
      # Build the Git URL
      url = "#{git_url}/api/v3/repos/#{git_org}/#{git_repo}/pulls"
      # Download the JSON Data from the API
      begin
        resp = Net::HTTP.get_response(URI.parse(url))
        pulls = JSON.parse(resp.body)
        pulls.map { |p| { number: p['number'], base: p['base']['ref'] } }
      rescue StandardError
        raise 'Failed connecting to github!'
      end
    end
  end
end
