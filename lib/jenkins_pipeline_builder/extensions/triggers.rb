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

trigger do
  name :git_push
  plugin_id 'github'
  description 'This plugin integrates Jenkins with Github projects.

The plugin currently has two major functionalities:

  * Create hyperlinks between your Jenkins projects and GitHub
  * Trigger a job when you push to the repository by groking HTTP POSTs from post-receive hook and optionally auto-managing the hook setup.'

  jenkins_name 'Build when a change is pushed to GitHub'
  announced false

  xml do |_|
    send('com.cloudbees.jenkins.GitHubPushTrigger') do
      spec
    end
  end
end

trigger do
  name :scm_polling
  plugin_id 'builtin'
  description 'Poll selected SCM for changes and builds if there are any changes.'
  jenkins_name 'Poll SCM'
  announced false

  xml do |scm_polling|
    send('hudson.triggers.SCMTrigger') do
      spec scm_polling
      ignorePostCommitHooks false
    end
  end
end

trigger do
  name :periodic_build
  plugin_id 'builtin'
  description 'Builts the job at selected interval'
  jenkins_name 'Build periodically'
  announced false

  xml do |periodic_build|
    send('hudson.triggers.TimerTrigger') do
      spec periodic_build
    end
  end
end

trigger do
  name :upstream
  plugin_id 'builtin'
  description 'Build when an upstream job finishes'
  jenkins_name 'Build after other projects are built'
  announced false

  xml do |params|
    send('jenkins.triggers.ReverseBuildTrigger') do
      spec
      upstreamProjects params[:projects]
      send('threshold') do
        name helper.name
        ordinal helper.ordinal
        color helper.color
        completeBuild true
      end
    end
  end
end
