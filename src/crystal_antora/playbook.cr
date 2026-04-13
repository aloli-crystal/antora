require "yaml"

module CrystalAntora
  class Playbook
    class SiteConfig
      property title : String
      property url : String
      property start_page : String

      def initialize(@title = "Documentation", @url = "http://localhost:4000", @start_page = "")
      end
    end

    class ContentSource
      property url : String
      property branches : String
      property start_path : String

      def initialize(@url = ".", @branches = "HEAD", @start_path = ".")
      end
    end

    class UIConfig
      property bundle : String

      def initialize(@bundle = "default")
      end
    end

    class OutputConfig
      property dir : String

      def initialize(@dir = "./build/site")
      end
    end

    class SAMLConfig
      property idp_sso_url : String
      property idp_cert : String
      property sp_entity_id : String
      property assertion_consumer_url : String

      def initialize(
        @idp_sso_url = "",
        @idp_cert = "",
        @sp_entity_id = "",
        @assertion_consumer_url = ""
      )
      end
    end

    class AuthConfig
      property enabled : Bool
      property provider : String
      property protected_components : Array(String)
      property protected_modules : Array(String)
      property login_page : String
      property session_secret : String
      property saml : SAMLConfig

      def initialize(
        @enabled = false,
        @provider = "kemal-auth",
        @protected_components = [] of String,
        @protected_modules = [] of String,
        @login_page = "/login",
        @session_secret = "",
        @saml = SAMLConfig.new
      )
      end
    end

    class ServerConfig
      property host : String
      property port : Int32
      property livereload : Bool

      def initialize(@host = "localhost", @port = 4000, @livereload = true)
      end
    end

    property site : SiteConfig
    property content_sources : Array(ContentSource)
    property ui : UIConfig
    property output : OutputConfig
    property auth : AuthConfig
    property server : ServerConfig

    def initialize(
      @site = SiteConfig.new,
      @content_sources = [ContentSource.new],
      @ui = UIConfig.new,
      @output = OutputConfig.new,
      @auth = AuthConfig.new,
      @server = ServerConfig.new
    )
    end

    def self.load(path : String) : Playbook
      raw = File.read(path)
      resolved = substitute_env_vars(raw)
      data = YAML.parse(resolved)
      from_yaml(data)
    end

    def self.substitute_env_vars(text : String) : String
      text.gsub(/\$\{([^}]+)\}/) do |match|
        var_name = $1
        ENV[var_name]? || ""
      end
    end

    def self.from_yaml(data : YAML::Any) : Playbook
      playbook = Playbook.new

      if site_data = data["site"]?
        playbook.site.title = site_data["title"]?.try(&.as_s) || "Documentation"
        playbook.site.url = site_data["url"]?.try(&.as_s) || "http://localhost:4000"
        playbook.site.start_page = site_data["start_page"]?.try(&.as_s) || ""
      end

      if content_data = data["content"]?
        if sources = content_data["sources"]?
          playbook.content_sources = sources.as_a.map do |src|
            cs = ContentSource.new
            cs.url = src["url"]?.try(&.as_s) || "."
            cs.branches = src["branches"]?.try(&.as_s) || "HEAD"
            cs.start_path = src["start_path"]?.try(&.as_s) || "."
            cs
          end
        end
      end

      if ui_data = data["ui"]?
        playbook.ui.bundle = ui_data["bundle"]?.try(&.as_s) || "default"
      end

      if output_data = data["output"]?
        playbook.output.dir = output_data["dir"]?.try(&.as_s) || "./build/site"
      end

      if auth_data = data["auth"]?
        playbook.auth.enabled = auth_data["enabled"]?.try(&.as_bool) || false
        playbook.auth.provider = auth_data["provider"]?.try(&.as_s) || "kemal-auth"
        if pc = auth_data["protected_components"]?
          playbook.auth.protected_components = pc.as_a.map(&.as_s)
        end
        if pm = auth_data["protected_modules"]?
          playbook.auth.protected_modules = pm.as_a.map(&.as_s)
        end
        playbook.auth.login_page = auth_data["login_page"]?.try(&.as_s) || "/login"
        playbook.auth.session_secret = auth_data["session_secret"]?.try(&.as_s) || ""

        if saml_data = auth_data["saml"]?
          playbook.auth.saml.idp_sso_url = saml_data["idp_sso_url"]?.try(&.as_s) || ""
          playbook.auth.saml.idp_cert = saml_data["idp_cert"]?.try(&.as_s) || ""
          playbook.auth.saml.sp_entity_id = saml_data["sp_entity_id"]?.try(&.as_s) || ""
          playbook.auth.saml.assertion_consumer_url = saml_data["assertion_consumer_url"]?.try(&.as_s) || ""
        end
      end

      if server_data = data["server"]?
        playbook.server.host = server_data["host"]?.try(&.as_s) || "localhost"
        playbook.server.port = (server_data["port"]?.try(&.as_i) || 4000).to_i32
        playbook.server.livereload = server_data["livereload"]?.try(&.as_bool) != false
      end

      playbook
    end
  end
end
