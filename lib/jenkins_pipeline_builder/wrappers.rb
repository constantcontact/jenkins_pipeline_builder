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

require 'jenkins_pipeline_builder/extensions'

wrapper do
  name :ansicolor
  plugin_id 123
  min_version 0
  announced false
  jenkins_name 'color ansi'
  description 'this is a description'
  xml do |_|
    send('hudson.plugins.ansicolor.AnsiColorBuildWrapper') do
      colorMapName 'xterm'
    end
  end
end

wrapper do
  name :timestamp
  plugin_id 123
  min_version 0
  announced false

  xml do |_|
    send('hudson.plugins.timestamper.TimestamperBuildWrapper', 'plugin' => 'timestamper')
  end
end

wrapper do
  name :rvm05
  plugin_id 123
  min_version '0.5'
  announced false

  xml do |wrapper|
    send('ruby-proxy-object') do
      send('ruby-object', 'ruby-class' => 'Jenkins::Tasks::BuildWrapperProxy', 'pluginid' => 'rvm') do
        object('ruby-class' => 'RvmWrapper', 'pluginid' => 'rvm') do
          impl('pluginid' => 'rvm', 'ruby-class' => 'String') { text wrapper }
        end
        pluginid(:pluginid => 'rvm', 'ruby-class' => 'String') { text 'rvm' }
      end
    end
  end
end

wrapper do
  name :name
  plugin_id 123
  min_version 0
  announced false

  xml do |_|
  end
end

wrapper do
  name :rvm
  plugin_id 123
  min_version 0
  announced false

  xml do |wrapper|
    send('ruby-proxy-object') do
      send('ruby-object', 'ruby-class' => 'Jenkins::Plugin::Proxies::BuildWrapper', 'pluginid' => 'rvm') do
        object('ruby-class' => 'RvmWrapper', 'pluginid' => 'rvm') do
          impl('pluginid' => 'rvm', 'ruby-class' => 'String') do
            text wrapper
          end
        end
        pluginid(:pluginid => 'rvm', 'ruby-class' => 'String') { text 'rvm' }
      end
    end
  end
end

wrapper do
  name :inject_passwords
  plugin_id 123
  min_version 0
  announced false

  xml do |passwords|
    EnvInjectPasswordWrapper do
      injectGlobalPasswords false
      passwordEntries do
        passwords.each do |password|
          EnvInjectPasswordEntry do
            name password[:name]
            value password[:value]
          end
        end
      end
    end
  end
end

wrapper do
  name :inject_env_var
  plugin_id 123
  min_version 0
  announced false

  xml do |params|
    EnvInjectBuildWrapper do
      info do
        propertiesFilePath params[:file] if params[:file]
        propertiesContent params[:content] if params[:content]
        loadFilesFromMaster false
      end
    end
  end
end

wrapper do
  name :artifactory
  plugin_id 123
  min_version 0
  announced false

  xml do |wrapper|
    send('org.jfrog.hudson.generic.ArtifactoryGenericConfigurator') do
      details do
        artifactoryUrl wrapper[:url]
        artifactoryName wrapper[:'artifactory-name']
        repositoryKey wrapper[:'release-repo']
        snapshotsRepositoryKey wrapper.fetch(:'snapshot-repo', wrapper[:'release-repo'])
      end
      deployPattern wrapper[:publish]
      resolvePattern
      matrixParams wrapper[:properties]
      deployBuildInfo wrapper[:'publish-build-info']
      includeEnvVars false
      envVarsPatterns do
        includePatterns
        excludePatterns '*password*,*secret*'
      end
      discardOldBuilds false
      discardBuildArtifacts true
    end
  end
end

wrapper do
  name :maven3artifactory
  plugin_id 123
  min_version 0
  announced false

  xml do |wrapper|
    send('org.jfrog.hudson.maven3.ArtifactoryMaven3Configurator') do # plugin='artifactory@2.2.1'
      details do
        artifactoryUrl wrapper[:url]
        artifactoryName wrapper[:'artifactory-name']
        repositoryKey wrapper[:'release-repo']
        snapshotsRepositoryKey wrapper.fetch(:'snapshot-repo', wrapper[:'release-repo'])
      end
      deployArtifacts wrapper.fetch(:'deploy', true)
      artifactDeploymentPatterns do
        includePatterns
        excludePatterns
      end
      includeEnvVars false
      deployBuildInfo wrapper.fetch(:'publish-build-info', true)
      envVarsPatterns do
        includePatterns
        excludePatterns '*password*,*secret*'
      end
      runChecks false
      violationRecipients
      includePublishArtifacts false
      scopes
      licenseAutoDiscovery true
      disableLicenseAutoDiscovery false
      discardOldBuilds false
      discardBuildArtifacts true
      matrixParams
      enableIssueTrackerIntegration false
      aggregateBuildIssues false
      blackDuckRunChecks false
      blackDuckAppName
      blackDuckAppVersion
      blackDuckReportRecipients
      blackDuckScopes
      blackDuckIncludePublishedArtifacts false
      autoCreateMissingComponentRequests true
      autoDiscardStaleComponentRequests true
      filterExcludedArtifactsFromBuild false
    end
  end
end
