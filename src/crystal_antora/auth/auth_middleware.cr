module CrystalAntora
  module Auth
    class AuthMiddleware
      property playbook : Playbook
      property sessions : Hash(String, AuthSession)

      def initialize(@playbook : Playbook)
        @sessions = {} of String => AuthSession
      end

      def enabled? : Bool
        playbook.auth.enabled
      end

      def protected?(path : String) : Bool
        return false unless enabled?

        components = playbook.auth.protected_components
        modules = playbook.auth.protected_modules

        if components.empty? && modules.empty?
          return true
        end

        components.each do |comp|
          return true if path.starts_with?("/#{comp}/") || path == "/#{comp}"
        end

        modules.each do |mod|
          return true if path.includes?("/#{mod}/")
        end

        false
      end

      def authenticated?(session_id : String?) : Bool
        return true unless enabled?
        return false unless session_id
        sessions.has_key?(session_id)
      end

      def create_session(user : AuthUser) : String
        session_id = Random::Secure.hex(32)
        sessions[session_id] = AuthSession.new(user: user, created_at: Time.utc)
        session_id
      end

      def get_session(session_id : String) : AuthSession?
        sessions[session_id]?
      end

      def destroy_session(session_id : String)
        sessions.delete(session_id)
      end

      def login_page : String
        playbook.auth.login_page
      end

      def provider : String
        playbook.auth.provider
      end
    end

    class AuthUser
      property name : String
      property email : String
      property attributes : Hash(String, String)

      def initialize(@name = "", @email = "", @attributes = {} of String => String)
      end
    end

    class AuthSession
      property user : AuthUser
      property created_at : Time

      def initialize(@user : AuthUser, @created_at = Time.utc)
      end
    end
  end
end
