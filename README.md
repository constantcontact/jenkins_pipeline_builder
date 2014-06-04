jenkins-pipeline-builder
========================

YAML driven CI Jenkins Pipeline Builder enabling to version your artifact pipelines alongside with the artifact source
itself.

This Gem uses this methodolody by itself. Notice the 'pipeline' folder where we have a declaration of the Gem's build
pipeline.

# Background

This project is inspired by a great work done by Arangamani with [jenkins_api_client](https://github.com/arangamani/jenkins_api_client) and
amazing progress done by the Open Stack community with their [jenkins-job-builder](http://ci.openstack.org/jenkins-job-builder/)

The YAML structure very closely resembles the OpenStack Job Builder, but, in comparison to Python version, is 100%
pure Ruby and uses Jenkins API Client and has additional functionlity of building different types of Jenkins views.

# JenkinsPipeline::Generator

USAGE:
------

### Installation

Add this line to your application's Gemfile:

    gem 'jenkins_pipeline_builder'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jenkins_pipeline_builder

    brew install libxml2 libxslt
    [optional] brew link libxml2 libxslt
    gem install nokogiri

### Authentication

For more info see [jenkins_api_client](https://github.com/arangamani/jenkins_api_client).
Supplying credentials to the client is optional, as not all Jenkins instances
require authentication. This project supports two types of password-based
authentication. You can just you the plain password by using <tt>password</tt>
parameter. If you don't prefer leaving plain passwords in the credentials file,
you can encode your password in base64 format and use <tt>password_base64</tt>
parameter to specify the password either in the arguments or in the credentials
file. To use the client without credentials, just leave out the
<tt>username</tt> and <tt>password</tt> parameters. The <tt>password</tt>
parameter is only required if <tt>username</tt> is specified.

#### Using with Open ID

For more info see [jenkins_api_client](https://github.com/arangamani/jenkins_api_client).
It is very simple to authenticate with your Jenkins server that has Open ID
authentication enabled. You will have to obtain your API token and use the API
token as the password. For obtaining the API token, go to your user configuration
page and click 'Show API Token'. Use this token for the `password` parameter when
initializing the client.

### Basic usage

Create all your Job description files in a folder (Ex.: ./pipeline). Follow the Job/View/Project DSL.
Try to extract the reusable values out of jobs into the project.

Put the right information about the location of your Jenkins server and the appropriate credentials
in a config file (ex: config.login.yml)

Now you ready to bootstrap a pipeline:

    generate pipeline -c config/login.yml bootstrap ./pipeline

NOTE: you can run the pipeline in NOOP (debug-only) mode by addind -d parameter, like:

    generate pipeline -d -c config/login.yml bootstrap ./pipeline

DSL:
----

## Job DSL
Here's a high level overview of what's available:

```yaml
- job:
    name: nameStr # Name of your Job
    job_type: free_style # Optional  [free_style|multi_project]
    discard: # Discard old builds after:
      days: 1 # Optional, number of days after which the build is deleted
      number: 2 # Optional, number of builds after which the build is deleted
      artifact_days: 3 # Optional, number of days after which the artifact is deleted
      artifact_number: 4 # Optional, number of builds after which the artifact is deleted
    parameters:
      - name: param_name
        type: string
        default: default value
        description: text
    scm_provider: git # See more info on Jenkins Api Client
    scm_url: git@github.com:your_url_here
    scm_branch: master
    scm_params:
      excuded_users: user
      local_branch: branch_name
      recursive_update: true
      wipe_workspace: true
    shell_command: '. commit_build.sh'
    hipchat:
      room: room name here
      start-notify: true
    builders:
      - multi_job:
          phases:
            "Phase One":
              jobs:
                - name: first
                  exposed_scm: true
                  current_params: true
                  config:
                    predefined_build_parameters:
                      - "PARENT_WORKSPACE=${WORKSPACE}"
                - name: second
              continue_condition: COMPLETED
            "Phase Two":
              jobs:
                - name: third
      - inject_vars_file: build_job_info
      - shell_command: |
          echo 'Doing some work'
          run command1
      - maven3:
          goals: -B clean
          rootPom: path_to_pom
          mavenName: maven-name # Optional
    wrappers:
      - timestamp: true
      - ansicolor: true
      - artifactory:
          url: 'https://url.com/path'
          artifactory-name: 'key'
          release-repo: release
          snapshot-repo: snapshot
          publish: 'pkg/*.gem'
          publish-build-info: true # Optional
      - maven3artifactory:
          url: https://artifactory.com/artifactory
          artifactory-name: name
          release-repo: release
          snapshot-repo: snapshot
          publish-build-info: true # Optional
      - inject_env_var: |
          VAR1 = value_1
          VAR2 = value_2
      - inject_passwords:
        - name: pwd_name
          value: some_encrypted_password
      - rvm: "ruby-version@ruby-gemset"
    publishers:
      - junit_result:
          test_results: 'out/**/*.xml'
      - git:
          push-merge: true
          push-only-if-success: false
      - hipchat:
          jenkinsUrl: 'https://jenkins_url/'
          authToken: 'auth_token'
          room: 'room name'
      - coverage_result:
          report_dir: out/coverage/rcov
          total:
            healthy: 80
            unhealthy: 0
            unstable: 0
          code:
            healthy: 80
            unhealthy: 0
            unstable: 0
      - description_setter:
          regexp: See the build details at (.*)
          description: 'Build Details: <a href="\1">\1</a>'
      - downstream:
          project: project_name
          data:
            - params: |
                PARAM1=value1
                PARAM2=value2
            - file: promote-job-params
    triggers:
      - git_push: true
      - scm_polling: 'H/5 * * * *'
    build_flow: |
      guard {
        build("job_name1", param1: params["param1"]);
      } rescue {
        build("job_name2", param1: build21.environment.get("some_var"))
      }
```

### View DSL
```yaml
- view:
    name: 'view name'
    type: 'listview' # Optional: listview [default], myview, nestedView, categorizedView, dashboardView, multijobView
    description: 'description'
    parent_view: 'Parent View Name' # Optional, when you're using tested views
    regex: '.*'
    groupingRules: # Optional, when you are using Categorized view
      - groupRegex: "1.*"
        namingRule: "sub view"
```

### Project DSL
```yaml
- project:
    name: Your project name
    jobs:
      - Job1
      - Job2
          param1: value1
      - JobTemplate1
```

### Default Settings Section

The defaults section mimics behavior of [jenkins-job-builder Defaults](http://ci.openstack.org/jenkins-job-builder/configuration.html#defaults)
If a set of Defaults is specified with the name global, that will be used by all Job (and Job Template) definitions.

```yaml
- defaults:
    name: global
    param1: 'value 1'
```


CONTRIBUTING:
----------------

If you would like to contribute to this project, just do the following:

1. Fork the repo on Github.
2. Add your features and make commits to your forked repo.
3. Make a pull request to this repo.
4. Review will be done and changes will be requested.
5. Once changes are done or no changes are required, pull request will be merged.
6. The next release will have your changes in it.

Please take a look at the issues page if you want to get started.

FEATURE REQUEST:
----------------

If you use this gem for your project and you think it would be nice to have a
particular feature that is presently not implemented, I would love to hear that
and consider working on it. Just open an issue in Github as a feature request.

