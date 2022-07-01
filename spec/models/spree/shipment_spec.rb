# frozen_string_literal: true

RSpec.describe Spree::Shipment do
  describe '.between' do
    it 'delegates to BetweenQuery' do
      shipment = build_stubbed(:shipment)
      allow(SolidusBactracs::Shipment::BetweenQuery).to receive(:apply).with(
        any_args,
        from: Time.zone.yesterday,
        to: Time.zone.today,
      ).and_return([shipment])

      result = Spree::Deprecation.silence do
        described_class.between(Time.zone.yesterday, Time.zone.today)
      end

      expect(result).to eq([shipment])
    end

    it 'prints a deprecation warning' do
      allow(Spree::Deprecation).to receive(:warn)

      described_class.between(Time.zone.yesterday, Time.zone.today)

      expect(Spree::Deprecation).to have_received(:warn).with(/Spree::Shipment\.between/)
    end
  end

  describe '.exportable' do
    it 'delegates to ExportableQuery' do
      shipment = build_stubbed(:shipment)
      allow(SolidusBactracs::Shipment::ExportableQuery).to receive(:apply).and_return([shipment])

      result = Spree::Deprecation.silence do
        described_class.exportable
      end

      expect(result).to eq([shipment])
    end

    it 'prints a deprecation warning' do
      allow(Spree::Deprecation).to receive(:warn)

      described_class.exportable

      expect(Spree::Deprecation).to have_received(:warn).with(/Spree::Shipment\.exportable/)
    end
  end
end
