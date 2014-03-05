jenkins-pipeline-builder
========================

YAML driven CI Jenkins Pipeline Builder enabling to version your artifact pipelines alongside with the artifact source itself.


# JenkinsPipeline::Generator

TODO: Write a gem description

This is how you can bootstrap a pipeline:

    generate pipeline -d -c config/login.yml bootstrap ./pipeline-archetype

## Installation

Add this line to your application's Gemfile:

    gem 'jenkins_pipeline_builder'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jenkins_pipeline_builder

    brew install libxml2 libxslt
    [optional] brew link libxml2 libxslt
    gem install nokogiri

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Job DSL
Here's a high level overview of what's available:

```yaml
- job:
    name: nameStr # Name of your Job
    job_type: free_style # Optional  [free_style|multi_project]
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
      - job_builder:
          child_jobs:
            - job-name-1
            - job-name-2
          mark_phase: SUCCESSFUL
      - inject_vars_file: build_job_info
      - shell_command: |
          echo 'Doing some work'
          run command1
      - maven3:
          goals: -B clean
    wrappers:
      - timestamp: true
      - ansicolor: true
      - artifactory:
          url: 'https://url.com/path'
          artifactory-name: 'key'
          target-repo: gems-local
          publish: 'pkg/*.gem'
          publish-build-info: true
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
