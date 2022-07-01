# frozen_string_literal: true

module SolidusBactracs
  module Api
    class Client
      class << self
        def from_config
          new(
            request_runner: RequestRunner.new,
            error_handler: SolidusBactracs.config.error_handler,
            shipment_serializer: SolidusBactracs.config.api_shipment_serializer,
          )
        end
      end

      attr_reader :request_runner, :error_handler, :shipment_serializer

      def initialize(request_runner:, error_handler:, shipment_serializer:)
        @request_runner = request_runner
        @error_handler = error_handler
        @shipment_serializer = shipment_serializer
      end

      def bulk_create_orders(shipments)
        shipments.each do |shipment|
          SolidusBactracs::Api::SyncShipmentJob.perform_now(
            shipment_id: shipment.id,
            error_handler: @error_handler,
            shipment_serializer: @shipment_serializer,
            request_runner: @request_runner
          )
        end.compact
      end
    end
  end
end
