# frozen_string_literal: true
require "uri"
require "net/http"

module SolidusBactracs
  module Api
    class RequestRunner

      def initialize
        @username = SolidusBactracs.configuration.authentication_username
        @password = SolidusBactracs.configuration.authentication_password
        @api_base = SolidusBactracs.configuration.api_base
        @retries  = SolidusBactracs.configuration.api_retries
      end

      def authenticated_call(serializer: nil, shipment: nil, method: :post, path: '/webservices/rma/rmaservice.asmx', count: 0)
        if count <= @retries
          sguid = authenticate! rescue nil

          if !sguid.presence
            clear_cache
            count += 1
            self.authenticated_call(method: method, path: path, serializer: serializer, shipment: shipment, count: count)
          else
            params = serializer.call(shipment, sguid)

            rma_response = call(method: method, path: path, params: params)
            if create_rma_success?(rma_response)
              Rails.logger.info({ event: 'success CreateRMA', rma: shipment.number, response: parse_rma_creation_response(rma_response, "Message")})
              shipment_synced(shipment)
              return true
            elsif rma_exists?(rma_response) or rma_fail?(rma_response)
              return false
            else
              clear_cache
              count += 1
              Rails.logger.warn({ event: 'bactracs failed CreateRMA', error: parse_rma_creation_response(rma_response, "Message")})
              self.authenticated_call(method: method, path: path, serializer: serializer, shipment: shipment, count: count)
            end
          end
        else
          shipment_sync_failed(shipment)
          return false
        end
      end


      def call(method: nil, path: nil, params: {})
        doc = {}
        if params.present?
          doc = Nokogiri::XML(params.to_s)
        end
        response = HTTParty.send(
          method,
          URI.join(@api_base, path),
          body: doc.to_xml,
          http_proxyaddr: SolidusBactracs.configuration.proxy_address,
          http_proxyport: SolidusBactracs.configuration.proxy_port,
          http_proxyuser: SolidusBactracs.configuration.proxy_username,
          http_proxypass: SolidusBactracs.configuration.proxy_password,
          headers: {
            'Content-Type' => 'text/xml',
          },
        )

        case response.code.to_s
        when /2\d{2}/
          response
        when '429'
          raise RateLimitedError.from_response(response)
        else
          raise RequestError.from_response(response)
        end
      end

      def clear_cache
        Rails.cache.delete('bactracks_cache_key')
        @response = nil
      end

      def authenticate!
        unless @username.present? || @password.present? || @api_base.present?
          raise "Credentials not defined for Authentication"
        end

        @response = Rails.cache.fetch("backtracks_cache_key", expires_in: 1.hour, skip_nil: true) do
          self.call(method: :get, path: "/webservices/user/Authentication.asmx/Login?sUserName=#{@username}&sPassword=#{@password}")
        end

        raise RequestError.from_response(@response) unless @response # just try again for @retries?
        if "false" == parse_authentication_response(@response, "Result")
          Rails.logger.error({ event: 'bactracs auth failed', error: parse_authentication_response(@response, "Message")})
          raise RequestError.from_response(@response)
        end
        sguid = parse_authentication_response(@response, "Message")

        return sguid
      end

      def parse_authentication_response(response, field)
        response.dig("AuthenticationResponse", field)
      end

      def parse_rma_creation_response(response, field = "Result")
        response.dig("Envelope", "Body", "CreateNewResponse", "CreateNewResult", field).to_s.downcase
      end

      def create_rma_success?(response)
        parse_rma_creation_response(response) == 'true' && parse_rma_creation_response(response, "Message") == "ok"
      end

      def rma_exists?(response)
        if parse_rma_creation_response(response, "Message").match(/failed CreateRMA/)
          Rails.logger.error({ event: 'bactracs failed CreateRMA', error: parse_rma_creation_response(response, "Message")})
          return true
        end
      end

      def rma_fail?(response)
        if parse_rma_creation_response(response, "Message").match(/rma .* already exists/)
          Rails.logger.error({ event: 'bactracs failed CreateRMA', error: parse_rma_creation_response(response, "Message")})
          return true
        end
      end


      def shipment_synced(shipment)
        shipment.update_attribute(:bactracs_synced_at, Time.zone.now)

        ::Spree::Bus.publish(:'solidus_bactracs.api.sync_completed', shipment: shipment)
      end

      def shipment_sync_failed(shipment)
        ::Spree::Bus.publish(:'solidus_bactracs.api.sync_failed', shipment:)
      end
    end
  end
end
