# frozen_string_literal: true

module SolidusBactracs
  module Api
    class SyncShipmentsJob# < ApplicationJob
      include Sidekiq::Worker

      sidekiq_options queue: 'default'

      def perform(shipment_ids)
        shipments = ::Spree::Shipment.where(id: shipment_ids)
        shipments = select_shipments(shipments)
        return if shipments.empty?

        sync_shipments(shipments)

        # Verify bactracs sync
        shipments.each { |shipment| VerifyBactracsSyncWorker.perform_async(shipment.id) }

      rescue RateLimitedError => e
        self.class.set(wait: e.retry_in).perform_async
      rescue StandardError => e
        SolidusBactracs.config.error_handler.call(e, {})
      end

      private

      def select_shipments(shipments)
        shipments.select do |shipment|
          if ThresholdVerifier.call(shipment)
            true
          else
            ::Spree::Bus.publish(:'solidus_bactracs.api.sync_skipped', shipment: shipment)

            false
          end
        end
      end

      def sync_shipments(shipments)
        BatchSyncer.from_config.call(shipments)
      end
    end
  end
end
