module Antora
  class DevServer
    property playbook : Playbook
    property catalog : ContentCatalog
    property composer : PageComposer
    property converter : Converter
    property auth_middleware : Auth::AuthMiddleware
    property last_update : Time
    property watched_files : Hash(String, Time)

    def initialize(@playbook : Playbook, @catalog : ContentCatalog, @composer : PageComposer, @converter : Converter)
      @auth_middleware = Auth::AuthMiddleware.new(playbook)
      @last_update = Time.utc
      @watched_files = {} of String => Time
      index_watched_files
    end

    def start
      host = playbook.server.host
      port = playbook.server.port

      if playbook.server.livereload
        spawn { watch_loop }
      end

      server = HTTP::Server.new do |context|
        handle_request(context)
      end

      address = server.bind_tcp(host, port)
      puts "Crystal Antora dev server running at http://#{address}"
      puts "Press Ctrl+C to stop"
      server.listen
    end

    private def handle_request(context : HTTP::Server::Context)
      path = context.request.path

      case path
      when "/_/livereload"
        context.response.content_type = "text/plain"
        context.response.print last_update.to_unix_ms.to_s
        return
      when "/login"
        if context.request.method == "GET"
          serve_login_page(context)
          return
        elsif context.request.method == "POST"
          handle_login(context)
          return
        end
      when "/logout"
        handle_logout(context)
        return
      when "/saml/login"
        handle_saml_login(context)
        return
      when "/saml/callback"
        handle_saml_callback(context)
        return
      when "/saml/metadata"
        handle_saml_metadata(context)
        return
      end

      if auth_middleware.enabled? && auth_middleware.protected?(path)
        session_id = extract_session_id(context)
        unless auth_middleware.authenticated?(session_id)
          context.response.status_code = 302
          context.response.headers["Location"] = auth_middleware.login_page
          return
        end
      end

      serve_static(context, path)
    end

    private def serve_static(context : HTTP::Server::Context, path : String)
      output_dir = playbook.output.dir

      file_path = if path == "/"
                    start = playbook.site.start_page
                    if start.empty?
                      first_page = catalog.pages.first?
                      if first_page
                        comp = first_page.component_name
                        name = first_page.basename.sub(/\.adoc\z/, ".html")
                        File.join(output_dir, comp, name)
                      else
                        File.join(output_dir, "index.html")
                      end
                    else
                      parts = start.split("::")
                      if parts.size == 2
                        File.join(output_dir, parts[0], parts[1].sub(/\.adoc\z/, ".html"))
                      else
                        File.join(output_dir, start.sub(/\.adoc\z/, ".html"))
                      end
                    end
                  else
                    File.join(output_dir, path.lstrip('/'))
                  end

      if File.exists?(file_path) && !File.directory?(file_path)
        context.response.content_type = mime_type(file_path)
        context.response.print File.read(file_path)
      else
        not_found = File.join(output_dir, "404.html")
        context.response.status_code = 404
        if File.exists?(not_found)
          context.response.content_type = "text/html"
          context.response.print File.read(not_found)
        else
          context.response.content_type = "text/plain"
          context.response.print "404 Not Found"
        end
      end
    end

    private def serve_login_page(context : HTTP::Server::Context)
      context.response.content_type = "text/html"
      context.response.print <<-HTML
      <!DOCTYPE html>
      <html><head><title>Login | #{HTML.escape(playbook.site.title)}</title>
      <style>#{Theme::CSS}</style></head>
      <body>
      <header class="site-header"><div class="header-inner">
        <a class="site-title" href="/">#{HTML.escape(playbook.site.title)}</a>
      </div></header>
      <div class="main-wrapper"><main class="content" style="max-width:400px;margin:2rem auto;">
        <h1>Login</h1>
        <form method="POST" action="/login" style="margin-top:1rem;">
          <div style="margin-bottom:1rem;">
            <label>Username</label><br>
            <input type="text" name="username" required style="width:100%;padding:0.5rem;">
          </div>
          <div style="margin-bottom:1rem;">
            <label>Password</label><br>
            <input type="password" name="password" required style="width:100%;padding:0.5rem;">
          </div>
          <button type="submit" style="padding:0.5rem 1.5rem;background:var(--color-brand);color:#fff;border:none;border-radius:4px;cursor:pointer;">Login</button>
        </form>
      </main></div></body></html>
      HTML
    end

    private def handle_login(context : HTTP::Server::Context)
      body = context.request.body.try(&.gets_to_end) || ""
      params = HTTP::Params.parse(body)
      username = params["username"]? || ""
      _password = params["password"]? || ""

      user = Auth::AuthUser.new(name: username, email: "#{username}@local")
      session_id = auth_middleware.create_session(user)

      context.response.cookies << HTTP::Cookie.new("antora_session", session_id, path: "/")
      context.response.status_code = 302
      context.response.headers["Location"] = "/"
    end

    private def handle_logout(context : HTTP::Server::Context)
      session_id = extract_session_id(context)
      auth_middleware.destroy_session(session_id) if session_id
      context.response.cookies << HTTP::Cookie.new("antora_session", "", path: "/", expires: Time.utc - 1.day)
      context.response.status_code = 302
      context.response.headers["Location"] = "/"
    end

    private def handle_saml_login(context : HTTP::Server::Context)
      saml_sp = Auth::SAMLServiceProvider.new(playbook.auth.saml)
      redirect_url = saml_sp.login_redirect_url
      context.response.status_code = 302
      context.response.headers["Location"] = redirect_url
    end

    private def handle_saml_callback(context : HTTP::Server::Context)
      body = context.request.body.try(&.gets_to_end) || ""
      params = HTTP::Params.parse(body)
      saml_response = params["SAMLResponse"]? || ""

      saml_sp = Auth::SAMLServiceProvider.new(playbook.auth.saml)
      user = saml_sp.parse_response(saml_response)

      if user
        session_id = auth_middleware.create_session(user)
        context.response.cookies << HTTP::Cookie.new("antora_session", session_id, path: "/")
        context.response.status_code = 302
        context.response.headers["Location"] = "/"
      else
        context.response.status_code = 401
        context.response.content_type = "text/plain"
        context.response.print "SAML authentication failed"
      end
    end

    private def handle_saml_metadata(context : HTTP::Server::Context)
      saml_sp = Auth::SAMLServiceProvider.new(playbook.auth.saml)
      context.response.content_type = "application/xml"
      context.response.print saml_sp.sp_metadata
    end

    private def extract_session_id(context : HTTP::Server::Context) : String?
      context.request.cookies["antora_session"]?.try(&.value)
    end

    private def mime_type(path : String) : String
      case File.extname(path).downcase
      when ".html"         then "text/html"
      when ".css"          then "text/css"
      when ".js"           then "application/javascript"
      when ".json"         then "application/json"
      when ".png"          then "image/png"
      when ".jpg", ".jpeg" then "image/jpeg"
      when ".gif"          then "image/gif"
      when ".svg"          then "image/svg+xml"
      when ".xml"          then "application/xml"
      when ".pdf"          then "application/pdf"
      when ".woff"         then "font/woff"
      when ".woff2"        then "font/woff2"
      else                      "application/octet-stream"
      end
    end

    private def index_watched_files
      catalog.files.each do |file|
        if File.exists?(file.path)
          watched_files[file.path] = File.info(file.path).modification_time
        end
      end
    end

    private def watch_loop
      loop do
        sleep 2.seconds
        changed = false

        watched_files.each do |path, mtime|
          if File.exists?(path)
            current_mtime = File.info(path).modification_time
            if current_mtime > mtime
              watched_files[path] = current_mtime
              changed = true
            end
          end
        end

        if changed
          @last_update = Time.utc
          rebuild
        end
      end
    end

    private def rebuild
      puts "File change detected, rebuilding..."
      aggregator = ContentAggregator.new(playbook)
      @catalog = aggregator.aggregate
      @converter = Converter.new(catalog)
      @composer = PageComposer.new(playbook, catalog, converter)
      publisher = SitePublisher.new(playbook, catalog, composer)
      publisher.publish
      puts "Rebuild complete."
    rescue ex
      puts "Rebuild failed: #{ex.message}"
    end
  end
end

require "html"
require "http/server"
require "uri"
