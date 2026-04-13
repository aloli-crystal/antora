require "spec"
require "../src/crystal_antora"
require "file_utils"

SPEC_TMP = File.join(Dir.tempdir, "crystal_antora_spec_#{Random::Secure.hex(4)}")

def setup_test_dir
  FileUtils.rm_rf(SPEC_TMP)
  FileUtils.mkdir_p(SPEC_TMP)
end

def cleanup_test_dir
  FileUtils.rm_rf(SPEC_TMP)
end

describe CrystalAntora do
  it "has a version" do
    CrystalAntora::VERSION.should eq "0.1.0"
  end
end

describe CrystalAntora::Playbook do
  describe ".substitute_env_vars" do
    it "replaces environment variables" do
      ENV["TEST_ANTORA_VAR"] = "hello_world"
      result = CrystalAntora::Playbook.substitute_env_vars("value: ${TEST_ANTORA_VAR}")
      result.should eq "value: hello_world"
      ENV.delete("TEST_ANTORA_VAR")
    end

    it "replaces missing env vars with empty string" do
      result = CrystalAntora::Playbook.substitute_env_vars("value: ${NONEXISTENT_TEST_VAR_XYZ}")
      result.should eq "value: "
    end
  end

  describe ".load" do
    it "parses a complete site.yml" do
      setup_test_dir
      site_yml = File.join(SPEC_TMP, "site.yml")
      File.write(site_yml, <<-YAML
      site:
        title: "Test Docs"
        url: https://test.example.com
        start_page: mycomp::index.adoc
      content:
        sources:
          - url: ./docs
            branches: HEAD
            start_path: .
      ui:
        bundle: default
      output:
        dir: ./build/site
      auth:
        enabled: true
        provider: kemal-auth
        protected_components:
          - admin
          - internal
        protected_modules: []
        login_page: /login
        session_secret: test-secret
        saml:
          idp_sso_url: https://idp.example.com/sso
          idp_cert: CERTDATA
          sp_entity_id: https://sp.example.com
          assertion_consumer_url: https://sp.example.com/saml/callback
      server:
        host: 0.0.0.0
        port: 8080
        livereload: false
      YAML
      )

      playbook = CrystalAntora::Playbook.load(site_yml)

      playbook.site.title.should eq "Test Docs"
      playbook.site.url.should eq "https://test.example.com"
      playbook.site.start_page.should eq "mycomp::index.adoc"

      playbook.content_sources.size.should eq 1
      playbook.content_sources[0].url.should eq "./docs"

      playbook.ui.bundle.should eq "default"
      playbook.output.dir.should eq "./build/site"

      playbook.auth.enabled.should be_true
      playbook.auth.provider.should eq "kemal-auth"
      playbook.auth.protected_components.should eq ["admin", "internal"]
      playbook.auth.login_page.should eq "/login"
      playbook.auth.session_secret.should eq "test-secret"
      playbook.auth.saml.idp_sso_url.should eq "https://idp.example.com/sso"
      playbook.auth.saml.sp_entity_id.should eq "https://sp.example.com"

      playbook.server.host.should eq "0.0.0.0"
      playbook.server.port.should eq 8080
      playbook.server.livereload.should be_false

      cleanup_test_dir
    end

    it "uses defaults for missing fields" do
      setup_test_dir
      site_yml = File.join(SPEC_TMP, "site.yml")
      File.write(site_yml, "site:\n  title: Minimal\n")

      playbook = CrystalAntora::Playbook.load(site_yml)
      playbook.site.title.should eq "Minimal"
      playbook.server.port.should eq 4000
      playbook.auth.enabled.should be_false
      playbook.output.dir.should eq "./build/site"

      cleanup_test_dir
    end

    it "substitutes env vars in playbook" do
      setup_test_dir
      ENV["ANTORA_TEST_SECRET"] = "my-secret-key"
      site_yml = File.join(SPEC_TMP, "site.yml")
      File.write(site_yml, <<-YAML
      site:
        title: EnvTest
      auth:
        enabled: false
        session_secret: ${ANTORA_TEST_SECRET}
      YAML
      )

      playbook = CrystalAntora::Playbook.load(site_yml)
      playbook.auth.session_secret.should eq "my-secret-key"

      ENV.delete("ANTORA_TEST_SECRET")
      cleanup_test_dir
    end
  end
end

describe CrystalAntora::Component do
  it "parses antora.yml" do
    setup_test_dir
    antora_yml = File.join(SPEC_TMP, "antora.yml")
    File.write(antora_yml, <<-YAML
    name: my-component
    title: My Component
    version: '1.0'
    nav:
      - modules/ROOT/nav.adoc
    YAML
    )

    component = CrystalAntora::Component.load(antora_yml)
    component.name.should eq "my-component"
    component.title.should eq "My Component"
    component.version.should eq "1.0"
    component.nav.should eq ["modules/ROOT/nav.adoc"]
    component.base_path.should eq SPEC_TMP

    cleanup_test_dir
  end

  it "uses name as title if title is missing" do
    setup_test_dir
    antora_yml = File.join(SPEC_TMP, "antora.yml")
    File.write(antora_yml, "name: only-name\nversion: '2.0'\n")

    component = CrystalAntora::Component.load(antora_yml)
    component.title.should eq "only-name"

    cleanup_test_dir
  end

  it "generates url_segment" do
    comp = CrystalAntora::Component.new(name: "docs", version: "2.0")
    comp.url_segment.should eq "docs/2.0"

    comp2 = CrystalAntora::Component.new(name: "docs", version: "")
    comp2.url_segment.should eq "docs"
  end
end

describe CrystalAntora::Classifier do
  it "classifies pages" do
    file = CrystalAntora::Classifier.classify("/project/modules/ROOT/pages/index.adoc", "mycomp")
    file.family.should eq CrystalAntora::FileFamily::Page
    file.component_name.should eq "mycomp"
    file.module_name.should eq "ROOT"
  end

  it "classifies partials" do
    file = CrystalAntora::Classifier.classify("/project/modules/ROOT/partials/header.adoc", "mycomp")
    file.family.should eq CrystalAntora::FileFamily::Partial
  end

  it "classifies images" do
    file = CrystalAntora::Classifier.classify("/project/modules/ROOT/images/logo.png", "mycomp")
    file.family.should eq CrystalAntora::FileFamily::Image
  end

  it "classifies attachments" do
    file = CrystalAntora::Classifier.classify("/project/modules/ROOT/attachments/doc.pdf", "mycomp")
    file.family.should eq CrystalAntora::FileFamily::Attachment
  end

  it "classifies examples" do
    file = CrystalAntora::Classifier.classify("/project/modules/ROOT/examples/sample.cr", "mycomp")
    file.family.should eq CrystalAntora::FileFamily::Example
  end

  it "extracts module name from path" do
    file = CrystalAntora::Classifier.classify("/project/modules/admin/pages/users.adoc", "mycomp")
    file.module_name.should eq "admin"
  end

  it "defaults to ROOT when no modules dir" do
    file = CrystalAntora::Classifier.classify("/project/pages/index.adoc", "mycomp")
    file.module_name.should eq "ROOT"
  end
end

describe CrystalAntora::Navigation do
  it "parses simple nav.adoc" do
    content = <<-NAV
    * xref:index.adoc[Home]
    * xref:getting-started.adoc[Getting Started]
    * xref:reference.adoc[Reference]
    NAV

    nav = CrystalAntora::Navigation.parse(content)
    nav.items.size.should eq 3
    nav.items[0].title.should eq "Home"
    nav.items[0].url.should eq "index.adoc"
    nav.items[1].title.should eq "Getting Started"
    nav.items[2].title.should eq "Reference"
  end

  it "parses nested nav.adoc" do
    content = <<-NAV
    * xref:index.adoc[Home]
    * xref:getting-started.adoc[Getting Started]
    ** xref:installation.adoc[Installation]
    ** xref:tutorial.adoc[Tutorial]
    * xref:reference.adoc[Reference]
    NAV

    nav = CrystalAntora::Navigation.parse(content)
    nav.items.size.should eq 3
    nav.items[1].children.size.should eq 2
    nav.items[1].children[0].title.should eq "Installation"
    nav.items[1].children[0].url.should eq "installation.adoc"
    nav.items[1].children[1].title.should eq "Tutorial"
  end

  it "finds prev/next pages" do
    content = <<-NAV
    * xref:page1.adoc[Page 1]
    * xref:page2.adoc[Page 2]
    * xref:page3.adoc[Page 3]
    NAV

    nav = CrystalAntora::Navigation.parse(content)

    prev_item, next_item = nav.find_prev_next("page2.adoc")
    prev_item.not_nil!.title.should eq "Page 1"
    next_item.not_nil!.title.should eq "Page 3"

    prev_item2, next_item2 = nav.find_prev_next("page1.adoc")
    prev_item2.should be_nil
    next_item2.not_nil!.title.should eq "Page 2"
  end

  it "finds breadcrumbs" do
    content = <<-NAV
    * xref:index.adoc[Home]
    * xref:getting-started.adoc[Getting Started]
    ** xref:installation.adoc[Installation]
    NAV

    nav = CrystalAntora::Navigation.parse(content)
    crumbs = nav.find_breadcrumbs("installation.adoc")
    crumbs.size.should eq 2
    crumbs[0].title.should eq "Getting Started"
    crumbs[1].title.should eq "Installation"
  end

  it "returns empty for unknown page" do
    nav = CrystalAntora::Navigation.parse("* xref:index.adoc[Home]")
    crumbs = nav.find_breadcrumbs("unknown.adoc")
    crumbs.should be_empty
  end
end

describe CrystalAntora::Converter do
  before_each { setup_test_dir }
  after_each { cleanup_test_dir }

  it "converts basic AsciiDoc to HTML" do
    catalog = CrystalAntora::ContentCatalog.new

    page_dir = File.join(SPEC_TMP, "modules", "ROOT", "pages")
    FileUtils.mkdir_p(page_dir)
    page_path = File.join(page_dir, "test.adoc")
    File.write(page_path, <<-ADOC
    = Test Page

    This is a paragraph.

    == Section One

    Some content here.

    === Subsection

    More content.
    ADOC
    )

    page = CrystalAntora::ContentFile.new(
      path: page_path,
      family: CrystalAntora::FileFamily::Page,
      module_name: "ROOT",
      component_name: "test",
      relative_path: "test.adoc"
    )

    converter = CrystalAntora::Converter.new(catalog)
    html = converter.convert(page)

    html.should contain("<h1>Test Page</h1>")
    html.should contain("<h2>Section One</h2>")
    html.should contain("<h3>Subsection</h3>")
    html.should contain("<p>")
    html.should contain("This is a paragraph.")
  end

  it "converts code blocks" do
    catalog = CrystalAntora::ContentCatalog.new

    page_dir = File.join(SPEC_TMP, "pages")
    FileUtils.mkdir_p(page_dir)
    page_path = File.join(page_dir, "code.adoc")
    File.write(page_path, <<-ADOC
    = Code Example

    [source,crystal]
    ----
    puts "Hello"
    ----
    ADOC
    )

    page = CrystalAntora::ContentFile.new(path: page_path, family: CrystalAntora::FileFamily::Page)
    converter = CrystalAntora::Converter.new(catalog)
    html = converter.convert(page)

    html.should contain("<pre><code")
    html.should contain("language-crystal")
    html.should contain("puts")
  end

  it "resolves xref links to .html" do
    catalog = CrystalAntora::ContentCatalog.new

    page_dir = File.join(SPEC_TMP, "pages")
    FileUtils.mkdir_p(page_dir)
    page_path = File.join(page_dir, "links.adoc")
    File.write(page_path, <<-ADOC
    = Links

    See xref:other.adoc[Other Page] for details.
    ADOC
    )

    page = CrystalAntora::ContentFile.new(path: page_path, family: CrystalAntora::FileFamily::Page)
    converter = CrystalAntora::Converter.new(catalog)
    html = converter.convert(page)

    html.should contain("other.html")
    html.should contain("Other Page")
  end

  it "extracts table of contents" do
    catalog = CrystalAntora::ContentCatalog.new
    converter = CrystalAntora::Converter.new(catalog)
    html = "<h2>First</h2><p>text</p><h3>Nested</h3><h2>Second</h2>"
    toc = converter.extract_toc(html)
    toc.size.should eq 3
    toc[0][:title].should eq "First"
    toc[0][:level].should eq 2
    toc[1][:title].should eq "Nested"
    toc[1][:level].should eq 3
    toc[2][:title].should eq "Second"
  end

  it "adds heading IDs" do
    catalog = CrystalAntora::ContentCatalog.new
    converter = CrystalAntora::Converter.new(catalog)
    html = "<h2>Getting Started</h2>"
    result = converter.add_heading_ids(html)
    result.should contain(%(id="getting-started"))
  end
end

describe CrystalAntora::PageComposer do
  before_each { setup_test_dir }
  after_each { cleanup_test_dir }

  it "composes a full HTML page" do
    playbook = CrystalAntora::Playbook.new
    playbook.site.title = "Test Site"
    playbook.server.livereload = false

    catalog = CrystalAntora::ContentCatalog.new

    page_dir = File.join(SPEC_TMP, "modules", "ROOT", "pages")
    FileUtils.mkdir_p(page_dir)
    page_path = File.join(page_dir, "index.adoc")
    File.write(page_path, <<-ADOC
    = Home Page

    Welcome to the docs.
    ADOC
    )

    page = CrystalAntora::ContentFile.new(
      path: page_path,
      family: CrystalAntora::FileFamily::Page,
      module_name: "ROOT",
      component_name: "test",
      relative_path: "index.adoc"
    )

    converter = CrystalAntora::Converter.new(catalog)
    composer = CrystalAntora::PageComposer.new(playbook, catalog, converter)
    html = composer.compose(page)

    html.should contain("<!DOCTYPE html>")
    html.should contain("Test Site")
    html.should contain("Home Page")
    html.should contain("Welcome to the docs.")
    html.should contain("<header")
    html.should contain("<footer")
    html.should contain("Crystal Antora")
  end

  it "includes navigation when provided" do
    playbook = CrystalAntora::Playbook.new
    playbook.server.livereload = false
    catalog = CrystalAntora::ContentCatalog.new

    page_dir = File.join(SPEC_TMP, "pages")
    FileUtils.mkdir_p(page_dir)
    page_path = File.join(page_dir, "index.adoc")
    File.write(page_path, "= Home\n\nContent.\n")

    page = CrystalAntora::ContentFile.new(path: page_path, family: CrystalAntora::FileFamily::Page)
    nav = CrystalAntora::Navigation.parse("* xref:index.adoc[Home]\n* xref:about.adoc[About]")

    converter = CrystalAntora::Converter.new(catalog)
    composer = CrystalAntora::PageComposer.new(playbook, catalog, converter)
    html = composer.compose(page, nav)

    html.should contain("nav-menu")
    html.should contain("About")
  end
end

describe CrystalAntora::SitePublisher do
  before_each { setup_test_dir }
  after_each { cleanup_test_dir }

  it "publishes site with correct structure" do
    playbook = CrystalAntora::Playbook.new
    playbook.site.title = "Publish Test"
    playbook.site.url = "https://test.example.com"
    playbook.server.livereload = false

    output_dir = File.join(SPEC_TMP, "build", "site")
    playbook.output.dir = output_dir

    catalog = CrystalAntora::ContentCatalog.new

    page_dir = File.join(SPEC_TMP, "src", "modules", "ROOT", "pages")
    FileUtils.mkdir_p(page_dir)
    page_path = File.join(page_dir, "index.adoc")
    File.write(page_path, "= Index\n\nHello world.\n")

    page = CrystalAntora::ContentFile.new(
      path: page_path,
      family: CrystalAntora::FileFamily::Page,
      module_name: "ROOT",
      component_name: "mycomp",
      relative_path: "index.adoc"
    )
    catalog.files << page

    converter = CrystalAntora::Converter.new(catalog)
    composer = CrystalAntora::PageComposer.new(playbook, catalog, converter)
    publisher = CrystalAntora::SitePublisher.new(playbook, catalog, composer)
    publisher.publish

    Dir.exists?(output_dir).should be_true
    File.exists?(File.join(output_dir, "mycomp", "index.html")).should be_true
    File.exists?(File.join(output_dir, "sitemap.xml")).should be_true
    File.exists?(File.join(output_dir, "404.html")).should be_true

    sitemap = File.read(File.join(output_dir, "sitemap.xml"))
    sitemap.should contain("https://test.example.com")
    sitemap.should contain("index.html")

    page_html = File.read(File.join(output_dir, "mycomp", "index.html"))
    page_html.should contain("Hello world")
  end

  it "copies images to output" do
    playbook = CrystalAntora::Playbook.new
    playbook.server.livereload = false
    output_dir = File.join(SPEC_TMP, "build", "site")
    playbook.output.dir = output_dir

    catalog = CrystalAntora::ContentCatalog.new

    img_dir = File.join(SPEC_TMP, "src", "modules", "ROOT", "images")
    FileUtils.mkdir_p(img_dir)
    img_path = File.join(img_dir, "logo.png")
    File.write(img_path, "FAKE_PNG_DATA")

    image = CrystalAntora::ContentFile.new(
      path: img_path,
      family: CrystalAntora::FileFamily::Image,
      module_name: "ROOT",
      component_name: "mycomp",
      relative_path: "logo.png"
    )
    catalog.files << image

    converter = CrystalAntora::Converter.new(catalog)
    composer = CrystalAntora::PageComposer.new(playbook, catalog, converter)
    publisher = CrystalAntora::SitePublisher.new(playbook, catalog, composer)
    publisher.publish

    File.exists?(File.join(output_dir, "_", "img", "mycomp", "ROOT", "logo.png")).should be_true
  end
end

describe CrystalAntora::Auth::AuthMiddleware do
  it "checks if path is protected" do
    playbook = CrystalAntora::Playbook.new
    playbook.auth.enabled = true
    playbook.auth.protected_components = ["admin", "internal"]

    middleware = CrystalAntora::Auth::AuthMiddleware.new(playbook)

    middleware.protected?("/admin/index.html").should be_true
    middleware.protected?("/internal/users.html").should be_true
    middleware.protected?("/public/index.html").should be_false
  end

  it "protects all paths when no components specified" do
    playbook = CrystalAntora::Playbook.new
    playbook.auth.enabled = true
    playbook.auth.protected_components = [] of String
    playbook.auth.protected_modules = [] of String

    middleware = CrystalAntora::Auth::AuthMiddleware.new(playbook)

    middleware.protected?("/anything").should be_true
  end

  it "is disabled by default" do
    playbook = CrystalAntora::Playbook.new
    middleware = CrystalAntora::Auth::AuthMiddleware.new(playbook)

    middleware.enabled?.should be_false
    middleware.protected?("/admin/index.html").should be_false
  end

  it "manages sessions" do
    playbook = CrystalAntora::Playbook.new
    playbook.auth.enabled = true

    middleware = CrystalAntora::Auth::AuthMiddleware.new(playbook)
    user = CrystalAntora::Auth::AuthUser.new(name: "testuser", email: "test@example.com")

    session_id = middleware.create_session(user)
    middleware.authenticated?(session_id).should be_true
    middleware.authenticated?("invalid").should be_false

    session = middleware.get_session(session_id)
    session.not_nil!.user.name.should eq "testuser"

    middleware.destroy_session(session_id)
    middleware.authenticated?(session_id).should be_false
  end
end

describe "Init command scaffold" do
  before_each { setup_test_dir }
  after_each { cleanup_test_dir }

  it "creates scaffold files" do
    Dir.cd(SPEC_TMP) do
      FileUtils.mkdir_p("modules/ROOT/pages")
      FileUtils.mkdir_p("modules/ROOT/partials")
      FileUtils.mkdir_p("modules/ROOT/images")
      FileUtils.mkdir_p("modules/ROOT/examples")
      FileUtils.mkdir_p("modules/ROOT/attachments")

      File.write("site.yml", <<-YAML
      site:
        title: "My Documentation"
      content:
        sources:
          - url: .
            branches: HEAD
            start_path: .
      ui:
        bundle: default
      output:
        dir: ./build/site
      auth:
        enabled: false
      server:
        host: localhost
        port: 4000
        livereload: true
      YAML
      )

      File.write("antora.yml", <<-YAML
      name: my-project
      title: My Project
      version: '1.0'
      nav:
        - modules/ROOT/nav.adoc
      YAML
      )

      File.write("modules/ROOT/nav.adoc", "* xref:index.adoc[Home]\n")

      File.write("modules/ROOT/pages/index.adoc", <<-ADOC
      = Welcome

      Welcome to your documentation site!
      ADOC
      )

      File.exists?("site.yml").should be_true
      File.exists?("antora.yml").should be_true
      Dir.exists?("modules/ROOT/pages").should be_true
      Dir.exists?("modules/ROOT/partials").should be_true
      Dir.exists?("modules/ROOT/images").should be_true
      Dir.exists?("modules/ROOT/examples").should be_true
      Dir.exists?("modules/ROOT/attachments").should be_true
      File.exists?("modules/ROOT/nav.adoc").should be_true
      File.exists?("modules/ROOT/pages/index.adoc").should be_true

      playbook = CrystalAntora::Playbook.load("site.yml")
      playbook.site.title.should eq "My Documentation"

      component = CrystalAntora::Component.load("antora.yml")
      component.name.should eq "my-project"
    end
  end
end
