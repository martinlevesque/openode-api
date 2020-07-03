class SuperAdmin::StatsController < SuperAdmin::SuperAdminController
  include Stats

  def spendings
    params['attrib_to_sum'] = 'credits_spent'
    params['entity'] = 'CreditAction'

    generic_daily_stats
  end

  def generic_daily_stats
    entity_method = params['entity_method']

    entity = params['entity'].constantize

    if entity_method.present?
      entity = entity.send(entity_method)
    end

    json(prepare_daily_stats(entity, params))
  end

  def nb_online
    nb_days = (params['nb_days'] || 30).to_i

    stats = SystemStat
            .where('created_at > ?', nb_days.days.ago)

    json(
      stats
      .map { |s| { date: s.created_at.to_date, value: s.obj.dig('nb_online') } }
      .sort_by do |e|
        e[:created_at]
      end
    )
  end
end
