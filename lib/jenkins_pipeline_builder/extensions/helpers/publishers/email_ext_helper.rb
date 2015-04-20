class EmailExtHelper < ExtensionHelper
  # rubocop:disable Metrics/MethodLength
  def trigger_defaults
    {
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
  end
  # rubocop:enable Metrics/MethodLength
end
