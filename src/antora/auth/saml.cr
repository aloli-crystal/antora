require "crystal-saml"

module Antora
  module Auth
    class SAMLServiceProvider
      property config : Playbook::SAMLConfig

      def initialize(@config : Playbook::SAMLConfig)
      end

      def settings : CrystalSaml::Settings
        s = CrystalSaml::Settings.new
        s.idp_sso_service_url = config.idp_sso_url
        s.idp_cert = config.idp_cert
        s.sp_entity_id = config.sp_entity_id
        s.assertion_consumer_service_url = config.assertion_consumer_url
        s.name_identifier_format = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
        s
      end

      def login_redirect_url : String
        request = CrystalSaml::AuthRequest.new(settings)
        request.redirect_url
      end

      def parse_response(saml_response_b64 : String) : AuthUser?
        begin
          response = CrystalSaml::Response.new(settings: settings, raw_base64: saml_response_b64)

          unless response.valid?(skip_signature: config.idp_cert.empty?)
            return nil
          end

          name_id = response.name_id || ""
          attributes = {} of String => String

          response.attributes.each do |key, values|
            attributes[key] = values.first? || ""
          end

          email = attributes["email"]? || (name_id.includes?("@") ? name_id : "")
          display_name = attributes["displayName"]? || name_id

          AuthUser.new(
            name: display_name,
            email: email,
            attributes: attributes
          )
        rescue ex
          nil
        end
      end

      def sp_metadata : String
        meta = CrystalSaml::Metadata.new(settings)
        meta.generate
      end
    end
  end
end
