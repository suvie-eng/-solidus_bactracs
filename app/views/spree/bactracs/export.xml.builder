# frozen_string_literal: true

xml = Builder::XmlMarkup.new
xml.instruct!
xml.Orders(pages: (@shipments.total_count / 50.0).ceil) {
  @shipments.each do |shipment|
    order = shipment.order

    xml.Order {
      xml.OrderID        shipment.id
      xml.OrderNumber    shipment.number # do not use shipment.order.number as this presents lookup issues
      xml.OrderDate      order.completed_at.strftime(SolidusBactracs::ExportHelper::DATE_FORMAT)
      xml.OrderStatus    shipment.state
      xml.LastModified   [order.completed_at, shipment.updated_at].max.strftime(SolidusBactracs::ExportHelper::DATE_FORMAT)
      xml.ShippingMethod shipment.shipping_method.try(:name)
      xml.OrderTotal     order.total
      xml.TaxAmount      order.tax_total
      xml.ShippingAmount order.ship_total
      xml.CustomField1   order.number

      #       if order.gift?
      #         xml.Gift
      #         xml.GiftMessage
      #       end

      xml.Customer {
        xml.CustomerCode order.email.slice(0, 50)
        SolidusBactracs::ExportHelper.address(xml, order, :bill)
        SolidusBactracs::ExportHelper.address(xml, order, :ship)
      }
      xml.Items {
        shipment.line_items.each do |line|
          variant = line.variant
          xml.Item {
            xml.SKU         variant.sku
            xml.Name        [variant.product.name, variant.options_text].join(' ')
            xml.ImageUrl    variant.images.first.try(:attachment).try(:url)
            xml.Weight      variant.weight.to_f
            xml.WeightUnits SolidusBactracs.configuration.weight_units
            xml.Quantity    line.quantity
            xml.UnitPrice   line.price

            if variant.option_values.present?
              xml.Options {
                variant.option_values.each do |value|
                  xml.Option {
                    xml.Name  value.option_type.presentation
                    xml.Value value.name
                  }
                end
              }
            end
          }
        end
      }
    }
  end
}
