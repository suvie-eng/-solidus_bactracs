# frozen_string_literal: true

module SolidusBactracs
  module Api
    class BatchSyncer
      class << self
        def from_config
          new(
            client: SolidusBactracs::Api::Client.from_config,
            shipment_matcher: SolidusBactracs.config.api_shipment_matcher,
          )
        end
      end

      attr_reader :client, :shipment_matcher

      def initialize(client:, shipment_matcher:)
        @client = client
        @shipment_matcher = shipment_matcher
      end

      def call(shipments)
        begin
          response = client.bulk_create_orders(shipments)
        rescue RateLimitedError => e
          ::Spree::Bus.publish(:'solidus_bactracs.api.rate_limited', shipments: shipments, error: e)

          raise e
        rescue RequestError => e
          ::Spree::Bus.publish(:'solidus_bactracs.api.sync_errored', shipments: shipments, error: e)

          raise e
        end
      end
    end
  end
end
