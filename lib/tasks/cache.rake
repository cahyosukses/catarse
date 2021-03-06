# frozen_string_literal: true

namespace :cache do
  desc 'Refresh reward metric storage from latest used rewards'
  task reward_metric_storages: [:environment] do
    loop do
      reward_to_refresh = []
      begin
        SubscriptionPayment.where("created_at > now() - '30 seconds'::interval").pluck(:reward_id).uniq.each do |rid|
          reward = Reward.find_by common_id: rid
          reward_to_refresh << reward
        end
      rescue StandardError => e
          Raven.extra_context(task: :cache_reward_metric_storage_subscription_payment_collection)
          Raven.capture_exception(e)
          Raven.extra_context({})
      end

      begin
        Contribution.where("created_at > now() - '30 seconds'::interval").pluck(:reward_id).uniq.each do |rid|
          reward = Reward.find rid
          reward_to_refresh << reward
        end
      rescue StandardError => e
          Raven.extra_context(task: :cache_reward_metric_contribution_collection)
          Raven.capture_exception(e)
          Raven.extra_context({})
      end

      reward_to_refresh.each do |reward|
        begin
          Rails.logger.debug("cache:reward_metric_storages -> refreshing reward: #{reward.id}")
          reward.refresh_reward_metric_storage
        rescue StandardError => e
          Raven.extra_context(task: :cache_reward_metric_storage, reward_id: reward.id)
          Raven.capture_exception(e)
          Raven.extra_context({})
        end
      end

      sleep 2
    end
  end
end
