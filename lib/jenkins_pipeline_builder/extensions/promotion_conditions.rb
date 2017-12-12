promotion_condition do
  name :manual
  plugin_id 'promoted-builds'
  parameters [
    :users
  ]

  xml do |params|
    send('hudson.plugins.promoted__builds.conditions.ManualCondition') do
      users params[:users]
    end
  end
end

promotion_condition do
  name :self_promotion
  plugin_id 'promoted-builds'
  parameters [
    :even_if_unstable
  ]

  xml do |params|
    send('hudson.plugins.promoted__builds.conditions.SelfPromotionCondition') do
      evenIfUnstable true if params[:even_if_unstable].nil?
      evenIfUnstable params[:even_if_unstable]
    end
  end
end

promotion_condition do
  name :parameterized_self_promotion
  plugin_id 'promoted-builds'
  parameters %i[
    parameter_name
    parameter_value
    even_if_unstable
  ]

  xml do |params|
    send('hudson.plugins.promoted__builds.conditions.ParameterizedSelfPromotionCondition') do
      parameterName params[:parameter_name]
      parameterValue true if params[:parameter_value].nil?
      evenIfUnstable true if params[:even_if_unstable].nil?
      parameterValue params[:parameter_value]
      evenIfUnstable params[:even_if_unstable]
    end
  end
end

promotion_condition do
  name :downstream_pass
  plugin_id 'promoted-builds'
  parameters %i[
    jobs
    even_if_unstable
  ]

  xml do |params|
    send('hudson.plugins.promoted__builds.conditions.DownstreamPassCondition') do
      jobs params[:jobs] || '{{Example}}-Commit'
      evenIfUnstable true if params[:even_if_unstable].nil?
      evenIfUnstable params[:even_if_unstable]
    end
  end
end

promotion_condition do
  name :upstream_promotion
  plugin_id 'promoted-builds'
  parameters [
    :promotion_name
  ]

  xml do |params|
    send('hudson.plugins.promoted__builds.conditions.UpstreamPromotionCondition') do
      promotionName '01. Staging Promotion' if params[:promotion_name].nil?
      promotionName params[:promotion_name]
    end
  end
end
