class CoberturaReportHelper < ExtensionHelper
  def thresholds
    @thresholds ||= params[:metric_targets]
    return @thresholds if @thresholds

    @thresholds = {
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

  def send_metric_targets(target)
    name = "#{target}Target"

    builder.instance_exec self do |helper|
      send name do
        targets 'class' => 'enum-map', 'enum-type' => 'hudson.plugins.cobertura.targets.CoverageMetric' do
          helper.thresholds[target].each do |threshold|
            entry do
              send('hudson.plugins.cobertura.targets.CoverageMetric') { text threshold[:type].upcase }
              send('int') { text(threshold[:value] * 100_000).to_i }
            end
          end
        end
      end
    end
  end
end
