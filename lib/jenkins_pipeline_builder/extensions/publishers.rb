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

publisher do
  name :brakeman
  plugin_id 'brakeman'
  description 'Parses results from Brakeman, a static-analysis vulnerability scanner for Ruby on Rails.'
  jenkins_name 'Brakeman Plugin'
  announced false

  xml do |params|

    send('hudson.plugins.brakeman.BrakemanPublisher', 'plugin' => 'brakeman') do
      healthy params[:healthy] || ''
      unHealthy params[:unhealthy] || ''
      thresholdLimit params[:threshold_limit] || 'low'
      pluginName '[BRAKEMAN] '
      defaultEncoding 'UTF-8'
      canRunOnFailed params[:can_run_on_failed] || false
      useStableBuildAsReference params[:use_stable_build_as_reference] || false
      useDeltaValues params[:use_delta_values] || false

      thresholds = params[:thresholds] || {}
      send('thresholds', 'plugin' => 'analysis-core') do
        unstableTotalAll { text(thresholds[:unstable_total_all] || '') }
        unstableTotalHigh { text(thresholds[:unstable_total_high] || '') }
        unstableTotalNormal { text(thresholds[:unstable_total_normal] || '') }
        unstableTotalLow { text(thresholds[:unstable_total_low] || '') }
        failedTotalAll { text(thresholds[:failed_total_all] || '') }
        failedTotalHigh { text(thresholds[:failed_total_high] || '') }
        failedTotalNormal { text(thresholds[:failed_total_normal] || '') }
        failedTotalLow { text(thresholds[:failed_total_low] || '') }
      end

      shouldDetectModules { text(params[:should_detect_modules] || false) }
      dontComputeNew { text(params[:dont_compute_new] || true) }
      doNotResolveRelativePaths { text(params[:do_not_resolve_relative_paths] || false) }
      outputFile { text(params[:output_file] || 'brakeman-output.tabs') }
    end

  end
end

publisher do
  name :claim_broken_build
  plugin_id 'claim'
  description 'This plugin allows users to claim failed builds.'
  jenkins_name 'Jenkins Claim Plugin'
  announced false

  xml do |allow_claim|
    send('hudson.plugins.claim.ClaimPublisher', 'plugin' => 'claim') if allow_claim
  end
end

publisher do
  name :cobertura_report
  plugin_id 'cobertura'
  description 'This plugin integrates Cobertura coverage reports to Jenkins.'
  jenkins_name 'Cobertura Plugin'
  announced false

  xml do |params|
    send('hudson.plugins.cobertura.CoberturaPublisher', 'plugin' => 'cobertura') do

      def send_metric_targets(target, thresholds)
        name = "#{target}Target"

        send name do
          targets 'class' => 'enum-map', 'enum-type' => 'hudson.plugins.cobertura.targets.CoverageMetric' do
            thresholds.each do |threshold|
              entry do
                send('hudson.plugins.cobertura.targets.CoverageMetric') { text threshold[:type].upcase }
                send('int') { text(threshold[:value] * 100_000).to_i }
              end
            end
          end
        end
      end

      coberturaReportFile params[:cobertura_report_file]
      onlyStable params[:only_stable] || false
      failUnhealthy params[:fail_unhealthy] || false
      failUnstable params[:fail_unstable] || false
      autoUpdateHealth params[:auto_update_health] || false
      autoUpdateStability params[:auto_update_stability] || false
      zoomCoverageChart params[:zoom_coverage_chart] || false
      maxNumberOfBuilds params[:max_number_of_builds] || 0
      failNoReports params[:fail_no_reports] || true

      targets = params[:metric_targets]
      if targets.nil?
        targets = {
          failing: [
            { type: 'type', value: 0 },
            { type: 'line', value: 0 },
            { type: 'conditional', value: 0 }
          ],
          unhealthy: [
            { type: 'type', value: 0 },
            { type: 'line', value: 0 },
            { type: 'conditional', value: 0 }
          ],
          healthy: [
            { type: 'type', value: 80 },
            { type: 'line', value: 80 },
            { type: 'conditional', value: 70 }
          ]
        }
      end

      send_metric_targets(:failing, targets[:failing])
      send_metric_targets(:unhealthy, targets[:unhealthy])
      send_metric_targets(:healthy, targets[:healthy])

      sourceEncoding params[:source_encoding] || 'ASCII'
    end
  end

end

publisher do
  name :email_ext
  plugin_id 'email-ext'
  description 'This plugin is a replacement for Jenkins\'s email publisher.'
  jenkins_name 'Email-ext plugin'
  announced false

  xml do |config|
    send('hudson.plugins.emailext.ExtendedEmailPublisher', 'plugin' => 'email-ext') do
      recipientList { text(config[:recipient_list] || '$DEFAULT_RECIPIENTS') }

      unless config[:triggers].nil?
        trigger_defaults = {
          first_failure: {
            name: 'FirstFailureTrigger',
            send_to_recipient_list: true,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          first_unstable: {
            name: 'FirstUnstableTrigger',
            send_to_recipient_list: false,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          second_failure: {
            name: 'SecondFailureTrigger',
            send_to_recipient_list: true,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          aborted: {
            name: 'AbortedTrigger',
            send_to_recipient_list: true,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          always: {
            name: 'AlwaysTrigger',
            send_to_recipient_list: true,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          before_build: {
            name: 'PreBuildTrigger',
            send_to_recipient_list: true,
            send_to_developers: false,
            send_to_requester: false,
            include_culprits: false
          },
          building: {
            name: 'BuildingTrigger',
            send_to_recipient_list: true,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          failure: {
            name: 'FailureTrigger',
            send_to_recipient_list: false,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          fixed: {
            name: 'FixedTrigger',
            send_to_recipient_list: true,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          fixed_unhealthy: {
            name: 'FixedUnhealthyTrigger',
            send_to_recipient_list: true,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          improvement: {
            name: 'ImprovementTrigger',
            send_to_recipient_list: true,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          not_built: {
            name: 'NotBuiltTrigger',
            send_to_recipient_list: true,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          prebuild_script: {
            name: 'PreBuildScriptTrigger',
            send_to_recipient_list: false,
            send_to_developers: false,
            send_to_requester: false,
            include_culprits: false
          },
          regression: {
            name: 'RegressionTrigger',
            send_to_recipient_list: true,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          script: {
            name: 'ScriptTrigger',
            send_to_recipient_list: true,
            send_to_developers: false,
            send_to_requester: false,
            include_culprits: false
          },
          status_changed: {
            name: 'StatusChangedTrigger',
            send_to_recipient_list: false,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          still_failing: {
            name: 'StillFailingTrigger',
            send_to_recipient_list: false,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          still_unstable: {
            name: 'StillUnstableTrigger',
            send_to_recipient_list: false,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          success: {
            name: 'SuccessTrigger',
            send_to_recipient_list: false,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          },
          unstable: {
            name: 'UnstableTrigger',
            send_to_recipient_list: false,
            send_to_developers: true,
            send_to_requester: false,
            include_culprits: false
          }
        }

        configuredTriggers do
          config[:triggers].each do |trigger_params|

            trigger_type = trigger_params[:type].to_sym
            defaults = trigger_defaults[trigger_type]

            send("hudson.plugins.emailext.plugins.trigger.#{defaults[:name]}") do
              email do
                recipientList { text(trigger_params[:recipient_list] || '') }
                subject { text(trigger_params[:subject] || '$PROJECT_DEFAULT_SUBJECT') }
                body { text(trigger_params[:body] || '$PROJECT_DEFAULT_CONTENT') }
                sendToDevelopers { text(!trigger_params[:send_to_developers].nil? ? trigger_params[:send_to_developers] : defaults[:send_to_developers]) }
                sendToRequester { text(!trigger_params[:send_to_requester].nil? ? trigger_params[:send_to_requester] : defaults[:send_to_requester]) }
                includeCulprits { text(!trigger_params[:include_culprits].nil? ? trigger_params[:include_culprits] : defaults[:include_culprits]) }
                sendToRecipientList { text(!trigger_params[:send_to_recipient_list].nil? ? trigger_params[:send_to_recipient_list] : defaults[:send_to_recipient_list]) }
                attachmentsPattern { text(trigger_params[:attachments_pattern] || '') }
                attachBuildLog { text(trigger_params[:attach_build_log] || false) }
                compressBuildLog { text(trigger_params[:compress_build_log] || false) }
                replyTo { text(trigger_params[:reply_to] || '$PROJECT_DEFAULT_REPLYTO') }
                contentType { text(trigger_params[:content_type] || 'project') }
              end

              failureCount { text '1' } if trigger_type == :first_failure
              failureCount { text '2' } if trigger_type == :second_failure
              if trigger_type == :prebuild_script || trigger_type == :script
                triggerScript { text(trigger_params[:trigger_script] || '') }
              end
            end
          end
        end
      end

      contentType { text(config[:content_type] || 'default') }
      defaultSubject { text(config[:default_subject] || '$DEFAULT_SUBJECT') }
      defaultContent { text(config[:default_content] || '$DEFAULT_CONTENT') }
      attachmentsPattern { text(config[:attachments_pattern] || '') }
      presendScript { text(config[:presend_script] || '$DEFAULT_PRESEND_SCRIPT') }
      attachBuildLog { text(config[:attach_build_log] || 'false') }
      compressBuildLog { text(config[:compress_build_log] || 'false') }
      replyTo { text(config[:reply_to] || '$DEFAULT_REPLYTO') }
      saveOutput { text(config[:save_output] || 'false') }
    end
  end
end

publisher do
  name :html_publisher
  plugin_id 'htmlpublisher'
  description 'This plugin publishes HTML reports.'
  jenkins_name 'HTML Publisher Plugin'
  announced false

  xml do |params|
    send('htmlpublisher.HtmlPublisher', 'plugin' => 'htmlpublisher') do
      send('reportTargets') do
        unless params[:report_targets].nil?
          params[:report_targets].each do |target|
            send('htmlpublisher.HtmlPublisherTarget') do
              reportName target[:report_title] || 'HTML Report'
              reportDir target[:report_dir] || ''
              reportFiles target[:index_pages] || 'index.html'
              keepAll target[:keep_past] || false
              allowMissing target[:allow_missing] || false
              wrapperName 'htmlpublisher-wrapper.html'
            end
          end
        end
      end
    end
  end
end

publisher do
  name :publish_tap_results
  plugin_id 'tap'
  description 'This plug-in adds support to TAP test result files to Jenkins. It lets you specify an ant-like pattern for a directory that contains your TAP files.'
  jenkins_name 'TAP Plugin'
  announced false

  xml do |params|
    send('org.tap4j.plugin.TapPublisher', 'plugin' => 'tap') do
      testResults params[:test_results]
      failIfNoResults params[:fail_if_no_results] || false
      failedTestsMarkBuildAsFailure params[:failed_test_mark_as_failure] || false
      outputTapToConsole params[:output_to_console] || false
      enableSubtests params[:enable_subtests] || false
      discardOldReports params[:discard_old_reports] || false
      todoIsFailure params[:todo_is_failure] || false
      includeCommentDiagnostics params[:include_comment_diagnostics] || false
      validateNumberOfTests params[:validate_number_tests] || false
    end
  end

end

publisher do
  name :xunit
  plugin_id 'xunit'
  description 'This plugin makes it possible to record xUnit test reports.'
  jenkins_name 'xUnit Plugin'
  announced false

  xml do |params|
    send('xunit', 'plugin' => 'xunit') do
      send('types') do
        unless params[:types].nil?
          params[:types].each do |type|
            send(type[:type]) do
              pattern type[:pattern]
              skipNoTestFiles type[:skip_no_test_files] || false
              failIfNotNew type[:fail_if_not_new] || true
              deleteOutputFiles type[:delete_output_files] || true
              stopProcessingIfError type[:stop_processing_error] || true
            end
          end
        end
      end

      params[:thresholds] ||= {}
      failed_thresholds = params[:thresholds][:failed] || {}
      skipped_thresholds = params[:thresholds][:skipped] || {}
      thresholds do
        send('org.jenkinsci.plugins.xunit.threshold.FailedThreshold') do
          unstableThreshold failed_thresholds[:unstable_threshold] || ''
          unstableNewThreshold failed_thresholds[:unstable_new_threshold] || ''
          failureThreshold failed_thresholds[:failure_threshold] || ''
          failureNewThreshold failed_thresholds[:failure_new_threshold] || ''
        end
        send('org.jenkinsci.plugins.xunit.threshold.SkippedThreshold') do
          unstableThreshold skipped_thresholds[:unstable_threshold] || ''
          unstableNewThreshold skipped_thresholds[:unstable_new_threshold] || ''
          failureThreshold skipped_thresholds[:failure_threshold] || ''
          failureNewThreshold skipped_thresholds[:failure_new_threshold] || ''
        end
      end

      thresholdMode params[:threshold_mode] || 1
    end
  end
end
