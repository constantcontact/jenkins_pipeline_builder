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

builder do
  name :multi_job
  plugin_id 'jenkins-multijob-plugin'
  description 'This plugin, created by Tikal ALM team, gives the option to define complex and hierarchical jobs structure in Jenkins.'
  jenkins_name 'MultiJob Phase'
  announced false

  xml do |params|
    params[:phases].each do |name, content|
      send('com.tikal.jenkins.plugins.multijob.MultiJobBuilder') do
        phaseName name
        phaseJobs do
          content[:jobs].each do |job|
            send('com.tikal.jenkins.plugins.multijob.PhaseJobsConfig') do
              jobName job[:name]
              currParams job[:current_params] || false
              exposedSCM job[:exposed_scm] || false
              if job[:config]
                configs do
                  if job[:config].key? :predefined_build_parameters
                    send('hudson.plugins.parameterizedtrigger.PredefinedBuildParameters') do
                      properties job[:config][:predefined_build_parameters]
                    end
                  end
                  if job[:config].key? :properties_file
                    send('hudson.plugins.parameterizedtrigger.FileBuildParameters') do
                      propertiesFile job[:config][:properties_file][:file]
                      failTriggerOnMissing job[:config][:properties_file][:skip_if_missing] || 'false'
                    end
                  end
                end
              end
              killPhaseOnJobResultCondition job[:kill_phase_on] || 'FAILURE'
            end
          end
        end
        continuationCondition content[:continue_condition] || 'SUCCESSFUL'
      end
    end
  end
end

builder do
  name :maven3
  plugin_id 'maven-plugin'
  description 'Jenkins plugin for building Maven 2/3 jobs via a special project type.'
  jenkins_name 'Invoke Maven 3'
  announced false

  xml do |params|
    send('org.jfrog.hudson.maven3.Maven3Builder') do
      mavenName params[:mavenName] || 'tools-maven-3.0.3'
      rootPom params[:rootPom]
      goals params[:goals]
      mavenOpts params[:options]
    end
  end
end

builder do
  name :shell_command
  plugin_id 'builtin'
  description 'Lets you run shell commands as a build step.'
  jenkins_name 'Execute shell'
  announced false

  xml do |param|
    send('hudson.tasks.Shell') do
      command param
    end
  end
end

builder do
  name :inject_vars_file
  plugin_id 'envinject'
  description 'This plugin makes it possible to have an isolated environment for your jobs.'
  jenkins_name 'Inject environment variables'
  announced false

  xml do |params|
    EnvInjectBuilder do
      info do
        propertiesFilePath params
      end
    end
  end
end

builder do
  name :blocking_downstream
  plugin_id 'parameterized-trigger'
  description 'This plugin lets you trigger new builds when your build has completed, with various ways of specifying parameters for the new build.'
  jenkins_name 'Trigger/call builds on other projects'
  announced false

  xml do |params|
    colors = {
      'SUCCESS' => { ordinal:  0, color:  'BLUE' },
      'FAILURE' => { ordinal:  2, color:  'RED' },
      'UNSTABLE' => { ordinal:  1, color:  'YELLOW' }
    }
    send('hudson.plugins.parameterizedtrigger.TriggerBuilder', 'plugin' => 'parameterized-trigger') do
      configs do
        send('hudson.plugins.parameterizedtrigger.BlockableBuildTriggerConfig') do
          configs do
            params[:data] = [{ params: '' }] unless params[:data]
            params[:data].each do |config|
              if config[:params]
                send('hudson.plugins.parameterizedtrigger.PredefinedBuildParameters') do
                  properties config[:params]
                end
              end
              if config[:file]
                send('hudson.plugins.parameterizedtrigger.FileBuildParameters') do
                  propertiesFile config[:file]
                  failTriggerOnMissing false
                end
              end
            end
          end
          projects params[:project]
          condition 'ALWAYS'
          triggerWithNoParameters params[:trigger_with_no_parameters] || false
          block do
            if params[:fail] && colors.include?(params[:fail])
              buildStepFailureThreshold do
                name params[:fail]
                ordinal colors[params[:fail]][:ordinal]
                color colors[params[:fail]][:color]
                completeBuild 'true'
              end
            end
            if params[:mark_fail] && colors.include?(params[:mark_fail])
              failureThreshold do
                name params[:mark_fail]
                ordinal colors[params[:mark_fail]][:ordinal]
                color colors[params[:mark_fail]][:color]
                completeBuild 'true'
              end
            end
            if params[:mark_unstable] && colors.include?(params[:mark_unstable])
              unstableThreshold do
                name params[:mark_unstable]
                ordinal colors[params[:mark_unstable]][:ordinal]
                color colors[params[:mark_unstable]][:color]
                completeBuild 'true'
              end
            end
          end
          buildAllNodesWithLabel false
        end
      end
    end
  end
end

builder do
  name :remote_job
  plugin_id 'Parameterized-Remote-Trigger'
  description 'A plugin for Jenkins CI that gives you the ability to trigger parameterized builds on a remote Jenkins server as part of your build.'
  jenkins_name 'Trigger a remote parameterized job'
  announced false

  xml do |params|
    param_list = params[:parameters][:content].split("\n") if params[:parameters] && params[:parameters][:content]
    send(
      'org.jenkinsci.plugins.ParameterizedRemoteTrigger.RemoteBuildConfiguration',
      'plugin' => 'Parameterized-Remote-Trigger'
    ) do
      remoteJenkinsName params[:server]
      job params[:job_name]
      shouldNotFailBuild params[:continue_on_remote_failure] if params[:continue_on_remote_failure]
      pollInterval params[:polling_interval] if params[:polling_interval]
      blockBuildUntilComplete params[:blocking] if params[:blocking]
      token
      if params[:parameters] && params[:parameters][:content]
        parameters params[:parameters][:content]
        parameterList do
          param_list.each do |p|
            string p
          end
        end
      elsif params[:parameters] && params[:parameters][:file]
        loadParamsFromFile 'true'
        parameterFile params[:parameters][:file]
      else
        # This was here for some reason?
        # parameters
        parameterList do
          string
        end
      end
      if params[:credentials] && params[:credentials][:type]
        overrideAuth 'true'
        auth do
          send('org.jenkinsci.plugins.ParameterizedRemoteTrigger.Auth') do
            if params[:credentials][:type] == 'api_token'
              authType 'apiToken'
              username params[:credentials][:username]
              API__TOKEN params[:credentials][:api_token]
            else
              authType 'none'
            end
          end
        end
      end
    end
  end
end

builder do
  name :copy_artifact
  plugin_id 'copyartifact'
  description 'Adds a build step to copy artifacts from another project. The plugin lets you specify which build to copy artifacts from (e.g. the last successful/stable build, by build number, or by a build parameter). You can also control the copying process by filtering the files being copied, specifying a destination directory within the target project, etc. Click the help icon on each field to learn the details, such as selecting Maven or multiconfiguration projects or using build parameters. You can also copy from the workspace of the latest completed build of the source project, instead of its artifacts. All artifacts copied are automatically fingerprinted for you.'
  jenkins_name 'Copy artifacts from another project'
  announced false

  xml do |params|
    send('hudson.plugins.copyartifact.CopyArtifact', 'plugin' => 'copyartifact') do
      project params[:project]
      filter params[:artifacts]
      target params[:target_directory]
      parameters params[:filter] if params[:filter]
      if params[:selector] && params[:selector][:type]
        case params[:selector][:type]
        when 'saved'
          send('selector', 'class' => 'hudson.plugins.copyartifact.SavedBuildSelector')
        when 'triggered'
          send('selector', 'class' => 'hudson.plugins.copyartifact.TriggeredBuildSelector') do
            fallbackToLastSuccessful params[:selector][:fallback] if params[:selector][:fallback]
          end
        when 'permalink'
          send('selector', 'class' => 'hudson.plugins.copyartifact.PermalinkBuildSelector') do
            id params[:selector][:id] if params[:selector][:id]
          end
        when 'specific'
          send('selector', 'class' => 'hudson.plugins.copyartifact.SpecificBuildSelector') do
            buildNumber params[:selector][:number] if params[:selector][:number]
          end
        when 'workspace'
          send('selector', 'class' => 'hudson.plugins.copyartifact.WorkspaceSelector')
        when 'parameter'
          send('selector', 'class' => 'hudson.plugins.copyartifact.ParameterizedBuildSelector') do
            parameterName params[:selector][:param] if params[:selector][:param]
          end
        else
          send('selector', 'class' => 'hudson.plugins.copyartifact.StatusBuildSelector') do
            stable params[:selector][:stable] if params[:selector][:stable]
          end
        end
      else
        send('selector', 'class' => 'hudson.plugins.copyartifact.StatusBuildSelector')
      end
      if params[:fingerprint].nil?
        doNotFingerprintArtifacts false
      else
        if params[:fingerprint].to_s == 'true'
          doNotFingerprintArtifacts false
        else
          doNotFingerprintArtifacts true
        end
      end
      flatten true if params[:flatten]
      optional true if params[:optional]
    end
  end
end
