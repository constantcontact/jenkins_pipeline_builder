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
  class PullRequest
    attr_reader :project    # The root project YAML as a hash
    attr_reader :number     # The pull request number
    attr_reader :jobs       # The jobs in the pull request as an array of hashes
    attr_reader :pull_generator  # The generator job YAML as a hash

    def initialize(project, number, jobs, pull_generator)
      @project = Marshal.load(Marshal.dump(project))
      @number = number
      @jobs = Marshal.load(Marshal.dump(jobs))
      @pull_generator = Marshal.load(Marshal.dump(pull_generator))
      @project[:value][:pull_request_number] = "#{@number}"

      run!
    end

    private

    def run!
      git_version = JenkinsPipelineBuilder.registry.registry[:job][:scm_params].installed_version
      if git_version >= Gem::Version.new(2.0)
        @jobs.each_value do |j|
          override_git_2_params j
        end
      end
      update_jobs!
      change_git!
      change_name!
    end

    def override_git_2_params(job)
      job[:value][:scm_params] ||= {}
      job[:value][:scm_params][:changelog_to_branch] = { remote: 'origin', branch: 'pr/{{pull_request_number}}/head' }
    end

    # Change the git branch for each job
    def change_git!
      @jobs.each_value do |job|
        job[:value][:scm_branch] = 'origin/pr/{{pull_request_number}}/head'
        job[:value][:scm_params] = {} unless job[:value][:scm_params]
        refspec = 'refs/pull/{{pull_request_number}}/head:refs/remotes/origin/pr/{{pull_request_number}}/head'
        job[:value][:scm_params][:refspec] = refspec
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
        @pull_generator[:value][:jobs].each do |gen|
          changes = gen[name.to_sym] if gen.is_a?(Hash) && gen.keys[0] == name.to_sym
        end
        # Apply changes
        Utils.hash_merge!(job[:value], changes) unless changes.nil?
      end
    end
  end
end
