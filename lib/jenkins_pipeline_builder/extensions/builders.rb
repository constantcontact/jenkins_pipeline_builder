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

  version '0' do
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

  version '1.27' do
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
                disableJob job[:disable_job] || false
                maxRetries job[:max_retries] || 0
                enableRetryStrategy job[:enable_retry_strategy] || false
                abortAllJob job[:abort_all_job] || false
                if job[:condition]
                  enableCondition true
                  condition job[:condition]
                  applyConditionOnlyIfNoSCMChanges job[:apply_condition_only_if]
                end

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
                buildOnlyIfSCMChanges job[:build_only_if_scm_changes] || false
              end
            end
          end
          continuationCondition content[:continue_condition] || 'SUCCESSFUL'
          executionType content[:execution_type] || 'PARALLEL'
        end
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
  parameters %i[
    mavenName
    rootPom
    goals
    options
  ]

  xml do |helper|
    send('org.jfrog.hudson.maven3.Maven3Builder') do
      mavenName helper.mavenName
      rootPom helper.rootPom
      goals helper.goals
      mavenOpts helper.options
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
  parameters %i[
    data
    project
    trigger_with_no_parameters
    fail
    mark_fail
    mark_unstable
  ]

  xml do |helper|
    send('hudson.plugins.parameterizedtrigger.TriggerBuilder', 'plugin' => 'parameterized-trigger') do
      configs do
        send('hudson.plugins.parameterizedtrigger.BlockableBuildTriggerConfig') do
          configs do
            helper.data
            helper.data.each do |config|
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
          projects helper[:project]
          condition 'ALWAYS'
          triggerWithNoParameters helper.trigger_with_no_parameters
          block do
            if helper.fail && helper.colors.include?(helper.fail)
              buildStepFailureThreshold do
                name helper.fail
                ordinal helper.colors[helper.fail][:ordinal]
                color helper.colors[helper.fail][:color]
                completeBuild 'true'
              end
            end
            if helper.mark_fail && helper.colors.include?(helper.mark_fail)
              failureThreshold do
                name helper.mark_fail
                ordinal helper.colors[helper.mark_fail][:ordinal]
                color helper.colors[helper.mark_fail][:color]
                completeBuild 'true'
              end
            end
            if helper.mark_unstable && helper.colors.include?(helper.mark_unstable)
              unstableThreshold do
                name helper.mark_unstable
                ordinal helper.colors[helper.mark_unstable][:ordinal]
                color helper.colors[helper.mark_unstable][:color]
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
      if params[:fingerprint].nil? || params[:fingerprint].to_s == 'true'
        doNotFingerprintArtifacts false
      else
        doNotFingerprintArtifacts true
      end
      flatten true if params[:flatten]
      optional true if params[:optional]
    end
  end
end

builder do
  name :system_groovy
  plugin_id 'groovy'
  description 'Lets you run groovy scripts as a build step.'
  jenkins_name 'System Groovy'
  announced false

  xml do |params|
    send('hudson.plugins.groovy.SystemGroovy', 'plugin' => 'groovy@1.24') do
      if params.key?(:script) && params.key?(:file)
        raise 'Configuration invalid. Both \'script\' and \'file\' keys can not be specified'
      end
      unless params.key?(:script) || params.key?(:file)
        raise 'Configuration invalid. At least one of \'script\' and \'file\' keys must be specified'
      end

      if params.key? :script
        scriptSource('class' => 'hudson.plugins.groovy.StringScriptSource') do
          command params[:script]
        end
      end

      if params.key? :file
        scriptSource('class' => 'hudson.plugins.groovy.FileScriptSource') do
          scriptFile params[:file]
        end
      end

      bindings params[:bindings]
      classpath params[:classpath]
    end
  end
end

builder do
  name :nodejs_script
  plugin_id 'nodejs'
  description 'Lets you run nodejs scripts as a build step.'
  jenkins_name 'Node_js script'
  announced false

  xml do |params|
    send('jenkins.plugins.nodejs.NodeJsCommandInterpreter', 'plugin' => 'nodejs@0.2.2') do
      command params[:script]
      nodeJSInstallationName params[:nodeJS_installation_name]
    end
  end
end

builder do
  name :checkmarx_scan
  plugin_id 'checkmarx'
  description 'Jenkins plugin for checkmarx security audit'
  jenkins_name 'Trigger a checkmarx security audit of your build'
  announced false
  parameters %i[
    serverUrl
    useOwnServerCredentials
    username
    password
    incremental
    isThisBuildIncremental
    projectName
    groupId
    skipSCMTriggers
    waitForResultsEnabled
    vulnerabilityThresholdEnabled
    highThreshold
    mediumThreshold
    lowThreshold
    preset
    presetSpecified
    generatePdfReport
    excludeFolders
    fullScansScheduled
    filterPattern
  ]

  xml do |params|
    send('com.checkmarx.jenkins.CxScanBuilder', 'plugin' => 'checkmarx@7.1.8-24') do
      useOwnServerCredentials params[:useOwnServerCredentials]
      serverUrl params[:serverUrl]
      useOwnServerCredentials params[:useOwnServerCredentials]
      username params[:username]
      password params[:password]
      incremental params[:incremental]
      isThisBuildIncremental params[:isThisBuildIncremental]
      projectName params[:projectName]
      groupId params[:groupId]
      skipSCMTriggers params[:skipSCMTriggers]
      waitForResultsEnabled params[:waitForResultsEnabled]
      vulnerabilityThresholdEnabled params[:vulnerabilityThresholdEnabled]
      highThreshold params[:highThreshold]
      mediumThreshold params[:mediumThreshold]
      lowThreshold params[:lowThreshold]
      generatePdfReport params[:generatePdfReport]
      excludeFolders params[:excludeFolders]
      presetSpecified params[:presetSpecified]
      preset params[:preset]
      fullScansScheduled params[:fullScansScheduled]
      filterPattern params[:filterPattern]
    end
  end
end

builder do
  name :sonar_standalone
  plugin_id 'sonar'
  description 'The plugin allows you to trigger SonarQube analysis from Jenkins using a Post-build action to trigger the analysis with MavenQuickly benefit from Sonar, the open source platform for Continuous Inspection of code quality.'
  jenkins_name 'SonarQube Plugin'
  announced false
  parameters %i[
    sonarInstallation
    taskToRun
    jdk
    pathToProjectProperties
    projectProperties
    jvmOptions
  ]

  xml do |params|
    send('hudson.plugins.sonar.SonarRunnerBuilder', 'plugin' => 'sonar@2.1') do
      installationName params[:sonarInstallation]
      jdk params[:jdk] || '(Inherit From Job)'
      project params[:pathToProjectProperties]
      properties params[:projectProperties]
      javaOpts params[:jvmOptions]
      task params[:taskToRun]
    end
  end
end

builder do
  name :conditional_multijob_step
  plugin_id 'conditional-buildstep'
  description 'description'
  jenkins_name 'Conditional Build Step'
  announced false

  xml do |params|
    send('org.jenkinsci.plugins.conditionalbuildstep.singlestep.SingleConditionalBuilder', 'plugin' => 'conditional-buildstep@1.3.3') do
      condition('class' => 'org.jenkins_ci.plugins.run_condition.contributed.ShellCondition', 'plugin' => 'run-condition@1.0') do
        command params[:conditional_shell]
      end
      params[:phases].each do |name, content|
        buildStep('class' => 'com.tikal.jenkins.plugins.multijob.MultiJobBuilder', 'plugin' => 'jenkins-multijob-plugin@1.13') do
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
      runner('class' => 'org.jenkins_ci.plugins.run_condition.BuildStepRunner$Fail', 'plugin' => 'run-condition@1.0')
    end
  end
end
