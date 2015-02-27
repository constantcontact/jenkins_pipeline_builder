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

publisher do
  name :description_setter
  plugin_id 'description-setter'
  description 'This plugin sets the description for each build, based upon a RegEx test of the build log file.'
  jenkins_name 'Set build description'
  announced false

  xml do |params|
    send('hudson.plugins.descriptionsetter.DescriptionSetterPublisher') do
      regexp params[:regexp]
      regexpForFailed params[:regexp]
      description params[:description]
      descriptionForFailed params[:description]
      setForMatrix false
    end
  end
end

publisher do
  name :downstream
  plugin_id 'parameterized-trigger'
  description 'This plugin lets you trigger new builds when your build has completed, with various ways of specifying parameters for the new build.'
  jenkins_name 'Trigger parameterized build on other projects'
  announced false

  xml do |params|
    send('hudson.plugins.parameterizedtrigger.BuildTrigger') do
      configs do
        send('hudson.plugins.parameterizedtrigger.BuildTriggerConfig') do
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
          condition params[:condition] || 'SUCCESS'
          triggerWithNoParameters params[:trigger_with_no_parameters] || false
        end
      end
    end
  end
end

publisher do
  name :hipchat
  plugin_id 'hipchat'
  description 'This plugin allows your team to setup build notifications to be sent to HipChat rooms.'
  jenkins_name 'HipChat Notifications'
  announced false

  xml do |params|
    params = {} if params == true
    send('jenkins.plugins.hipchat.HipChatNotifier') do
      jenkinsUrl params[:jenkinsUrl] || ''
      authToken params[:authToken] || ''
      room params[:room] || ''
    end
  end
end

publisher do
  name :git
  plugin_id 'git'
  description 'This plugin allows use of Git as a build SCM. A recent Git runtime is required (1.7.9 minimum, 1.8.x recommended). Plugin is only tested on official git client. Use exotic installations at your own risks.'
  jenkins_name 'Git Publisher'
  announced false

  xml do |params|
    send('hudson.plugins.git.GitPublisher') do
      configVersion params[:configVersion] || 2
      pushMerge params[:'push-merge'] || false
      pushOnlyIfSuccess params[:'push-only-if-success'] || false
      if params[:tag_name]
        tagsToPush do
          send 'hudson.plugins.git.GitPublisher_-TagToPush' do
            targetRepoName params[:target_repo]
            tagName params[:tag_name]
            createTag params[:create_tag] || false
          end
        end
      end
      branchesToPush do
        send('hudson.plugins.git.GitPublisher_-BranchToPush') do
          targetRepoName params[:targetRepoName] || 'origin'
          branchName params[:branchName] || 'master'
        end
      end
    end
  end
end

publisher do
  name :junit_result
  plugin_id 'builtin'
  description 'Archives your test results?'
  jenkins_name 'Publish JUnit test result report'
  announced false

  xml do |params|
    send('hudson.tasks.junit.JUnitResultArchiver') do
      testResults params[:test_results] || ''
      keepLongStdio false
      testDataPublishers
    end
  end
end

publisher do
  name :coverage_result
  plugin_id 'rubyMetrics'
  description 'Ruby metric reports for Jenkins. Rcov, Rails stats, Rails notes and Flog.'
  jenkins_name 'Publish Rcov report'
  announced false

  xml do |params|
    send('hudson.plugins.rubyMetrics.rcov.RcovPublisher') do
      reportDir params[:report_dir]
      targets do
        { 'TOTAL_COVERAGE' => params[:total], 'CODE_COVERAGE' => params[:code] }.each do |key, inner_params|
          send('hudson.plugins.rubyMetrics.rcov.model.MetricTarget') do
            metric key
            healthy inner_params[:healthy]
            unhealthy inner_params[:unhealthy]
            unstable inner_params[:unstable]
          end
        end
      end
    end
  end
end

publisher do
  name :post_build_script
  plugin_id 'postbuildscript'
  description 'PostBuildScript makes it possible to execute a set of scripts at the end of the build.'
  jenkins_name 'Execute a set of scripts'
  announced false

  xml do |params|
    send('org.jenkinsci.plugins.postbuildscript.PostBuildScript') do
      buildSteps do
        if params[:shell_command]
          send('hudson.tasks.Shell') do
            command params[:shell_command]
          end
        end
      end
      scriptOnlyIfSuccess params[:on_success]
      scriptOnlyIfFailure params[:on_failure]
      executeOn params[:execute_on] || 'BOTH'
    end
  end
end

publisher do
  name :groovy_postbuild
  plugin_id 'groovy-postbuild'
  description 'This plugin executes a groovy script in the Jenkins JVM. Typically, the script checks some conditions and changes accordingly the build result, puts badges next to the build in the build history and/or displays information on the build summary page.'
  jenkins_name 'Groovy Postbuild'
  announced false

  xml do |params|
    send('org.jvnet.hudson.plugins.groovypostbuild.GroovyPostbuildRecorder', 'plugin' => 'groovy-postbuild') do
      groovyScript params[:groovy_script]
      behavior params[:behavior] || '0'
      runFormMatrixParent 'false'
      if params[:additional_classpaths]
        params[:additional_classpaths].each do |path|
          send('org.jvnet.hudson.plugins.groovypostbuild.GroovyScriptPath') do
            path path[:path] || '/'
          end
        end
      end
    end
  end
end

publisher do
  name :archive_artifact
  plugin_id 'builtin'
  description 'Archives artifacts'
  jenkins_name 'Archive the artifacts'
  announced false

  xml do |params|
    send('hudson.tasks.ArtifactArchiver') do
      artifacts params[:artifacts]
      excludes params[:excludes] if params[:excludes]
      latestOnly params[:latest_only] || false
      allowEmptyArchive params[:allow_empty] || false

    end
  end
end

publisher do
  name :performance_plugin
  plugin_id 'performance'
  description 'JMeter Performance Plugin'
  jenkins_name 'JMeter Performance Plugin'
  announced false

  xml do |params|
    send 'hudson.plugins.performance.PerformancePublisher' do
      errorFailedThreshold params[:errorFailedThreshold] || '0'
      errorUnstableThreshold params[:errorUnstableThreshold] || '0'
      errorUnstableResponseTimeThreshold params[:errorUnstableResponseTimeThreshold]
      relativeFailedThresholdPositive params[:relativeFailedThresholdPositive] || '0.0'
      relativeFailedThresholdNegative params[:relativeFailedThresholdNegative] || '0.0'
      relativeUnstableThresholdPositive params[:relativeUnstableThresholdPositive] || '0.0'
      relativeUnstableThresholdNegative params[:relativeUnstableThresholdNegative] || '0.0'
      nthBuildNumber params[:nthBuildNumber] || '0'
      modeRelativeThresholds params[:modeRelativeThresholds] || 'false'
      configType params[:configType] || 'ART'
      modeOfThreshold params[:modeOfThreshold] || 'false'
      compareBuildPrevious params[:compareBuildPrevious] || 'false'
      modePerformancePerTestCase params[:modePerformancePerTestCase] || 'true'
      send 'parsers' do
        send 'hudson.plugins.performance.JMeterParser' do
          glob params[:result_file]
        end
      end
      modeThroughput params[:mode_throughput] || 'false'
    end
  end
end

publisher do
  name :email_notifications
  plugin_id 'mailer'
  description 'This plugin allows you to configure email notifications. This is a break-out of the original core based email component.'
  jenkins_name 'E-mail Notification'
  announced false

  xml do |params|
    send 'hudson.tasks.Mailer', 'plugin' => 'mailer' do
      recipients params[:recipients] || ''
      send_unstable = false
      send_unstable = true if params[:send_if_unstable] == false
      dontNotifyEveryUnstableBuild send_unstable
      sendToIndividuals params[:send_to_individuals] if params[:send_to_individuals]
    end
  end
end

publisher do
  name :sonar_result
  plugin_id 'sonar'
  description 'The plugin allows you to trigger SonarQube analysis from Jenkins using either a:
  * Build step to trigger the analysis with the SonarQube Runner
  * Post-build action to trigger the analysis with Maven'
  jenkins_name 'Sonar'
  announced false

  xml do |params|
    send('hudson.plugins.sonar.SonarPublisher') do
      jdk '(Inherit From Job)'
      branch params[:branch] || ''
      language
      mavenOpts
      jobAdditionalProperties
      mavenInstallationName params[:maven_installation_name] || ''
      rootPom params[:root_pom] || ''
      settings class: 'jenkins.mvn.DefaultSettingsProvider'
      globalSettings class: 'jenkins.mvn.DefaultGlobalSettingsProvider'
      usePrivateRepository false
    end
  end
end
