require "file_utils"

module Antora
  class SitePublisher
    property playbook : Playbook
    property catalog : ContentCatalog
    property composer : PageComposer

    def initialize(@playbook : Playbook, @catalog : ContentCatalog, @composer : PageComposer)
    end

    def publish
      output_dir = playbook.output.dir
      FileUtils.rm_rf(output_dir)
      FileUtils.mkdir_p(output_dir)

      publish_pages(output_dir)
      publish_images(output_dir)
      publish_attachments(output_dir)
      generate_sitemap(output_dir)
      generate_404(output_dir)
    end

    private def publish_pages(output_dir : String)
      catalog.pages.each do |page|
        navigation = find_navigation_for(page)
        html = composer.compose(page, navigation)

        relative = page.basename.sub(/\.adoc\z/, ".html")
        component_dir = File.join(output_dir, page.component_name)
        if page.module_name != "ROOT"
          component_dir = File.join(component_dir, page.module_name)
        end

        FileUtils.mkdir_p(component_dir)
        output_path = File.join(component_dir, relative)
        File.write(output_path, html)
      end
    end

    private def publish_images(output_dir : String)
      catalog.images.each do |image|
        dest_dir = File.join(output_dir, "_", "img", image.component_name, image.module_name)
        FileUtils.mkdir_p(dest_dir)
        dest = File.join(dest_dir, image.basename)
        FileUtils.cp(image.path, dest) if File.exists?(image.path)
      end
    end

    private def publish_attachments(output_dir : String)
      catalog.attachments.each do |attachment|
        dest_dir = File.join(output_dir, "_", "attachments", attachment.component_name, attachment.module_name)
        FileUtils.mkdir_p(dest_dir)
        dest = File.join(dest_dir, attachment.basename)
        FileUtils.cp(attachment.path, dest) if File.exists?(attachment.path)
      end
    end

    private def find_navigation_for(page : ContentFile) : Navigation?
      catalog.navigations.each do |key, nav|
        if key.starts_with?("#{page.component_name}:")
          return nav
        end
      end
      nil
    end

    private def generate_sitemap(output_dir : String)
      xml = String.build do |str|
        str << %(<?xml version="1.0" encoding="UTF-8"?>\n)
        str << %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n)
        catalog.pages.each do |page|
          relative = page.basename.sub(/\.adoc\z/, ".html")
          path = if page.module_name == "ROOT"
                   "/#{page.component_name}/#{relative}"
                 else
                   "/#{page.component_name}/#{page.module_name}/#{relative}"
                 end
          str << %(  <url>\n)
          str << %(    <loc>#{playbook.site.url}#{path}</loc>\n)
          str << %(  </url>\n)
        end
        str << %(</urlset>\n)
      end

      File.write(File.join(output_dir, "sitemap.xml"), xml)
    end

    private def generate_404(output_dir : String)
      html = <<-HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>404 - Page Not Found | #{HTML.escape(playbook.site.title)}</title>
        <style>
      #{Theme::CSS}
        </style>
      </head>
      <body>
        <header class="site-header">
          <div class="header-inner">
            <a class="site-title" href="/">#{HTML.escape(playbook.site.title)}</a>
          </div>
        </header>
        <div class="main-wrapper">
          <main class="content" style="text-align: center; padding: 4rem 2rem;">
            <h1>404</h1>
            <p>The page you are looking for does not exist.</p>
            <a href="/">Return to home</a>
          </main>
        </div>
        <footer class="site-footer">
          <p>Built with <a href="https://github.com/aloli-crystal/crystal-antora">Crystal Antora</a></p>
        </footer>
      </body>
      </html>
      HTML

      File.write(File.join(output_dir, "404.html"), html)
    end
  end
end

require "html"
