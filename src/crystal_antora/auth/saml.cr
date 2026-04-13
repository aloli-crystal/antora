require "base64"
require "xml"

module CrystalAntora
  module Auth
    class SAMLServiceProvider
      property config : Playbook::SAMLConfig

      def initialize(@config : Playbook::SAMLConfig)
      end

      def build_authn_request : String
        id = "_#{Random::Secure.hex(16)}"
        issue_instant = Time.utc.to_rfc3339

        xml = <<-XML
        <samlp:AuthnRequest
          xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
          xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
          ID="#{id}"
          Version="2.0"
          IssueInstant="#{issue_instant}"
          Destination="#{config.idp_sso_url}"
          AssertionConsumerServiceURL="#{config.assertion_consumer_url}"
          ProtocolBinding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST">
          <saml:Issuer>#{config.sp_entity_id}</saml:Issuer>
          <samlp:NameIDPolicy Format="urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress" AllowCreate="true"/>
        </samlp:AuthnRequest>
        XML

        xml
      end

      def login_redirect_url : String
        request_xml = build_authn_request
        encoded = Base64.strict_encode(request_xml)
        encoded_param = URI.encode_www_form(encoded)
        "#{config.idp_sso_url}?SAMLRequest=#{encoded_param}"
      end

      def parse_response(saml_response_b64 : String) : AuthUser?
        begin
          xml_str = Base64.decode_string(saml_response_b64)
          doc = XML.parse(xml_str)

          name_id = ""
          email = ""
          attributes = {} of String => String

          extract_from_xml(doc, name_id, email, attributes)

          user = AuthUser.new(
            name: attributes["displayName"]? || name_id,
            email: email.empty? ? name_id : email,
            attributes: attributes
          )

          user
        rescue ex
          nil
        end
      end

      private def extract_from_xml(node : XML::Node, name_id : String, email : String, attributes : Hash(String, String))
        if node.name == "NameID"
          content = node.content
          if content
            name_id = content.strip
            email = name_id if name_id.includes?("@")
          end
        end

        if node.name == "Attribute"
          attr_name = node["Name"]?
          if attr_name
            node.children.each do |child|
              if child.name == "AttributeValue"
                content = child.content
                attributes[attr_name] = content.strip if content
              end
            end
          end
        end

        node.children.each do |child|
          extract_from_xml(child, name_id, email, attributes)
        end
      end
    end
  end
end
