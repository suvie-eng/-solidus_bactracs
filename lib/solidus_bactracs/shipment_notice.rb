# frozen_string_literal: true

module SolidusBactracs
  class ShipmentNotice
    attr_reader :shipment_number, :shipment_tracking

    class << self
      def from_payload(params)
        new(
          shipment_number: params[:order_number],
          shipment_tracking: params[:tracking_number],
        )
      end
    end

    def initialize(shipment_number:, shipment_tracking:)
      @shipment_number = shipment_number
      @shipment_tracking = shipment_tracking
    end

    def apply
      unless shipment
        raise ShipmentNotFoundError, shipment
      end

      process_payment
      ship_shipment

      shipment
    end

    private

    def shipment
      @shipment ||= ::Spree::Shipment.find_by(number: shipment_number)
    end

    def process_payment
      return if shipment.order.paid?

      unless SolidusBactracs.configuration.capture_at_notification
        raise OrderNotPaidError, shipment.order
      end

      shipment.order.payments.pending.each do |payment|
        payment.capture!
      rescue ::Spree::Core::GatewayError
        raise PaymentError, payment
      end
    end

    def ship_shipment
      shipment.update!(tracking: shipment_tracking)
      shipment.ship! if shipment.can_ship?
      shipment.order.recalculate
    end
  end
end
