module CrystalAntora
  class PageComposer
    property playbook : Playbook
    property catalog : ContentCatalog
    property converter : Converter

    def initialize(@playbook : Playbook, @catalog : ContentCatalog, @converter : Converter)
    end

    def compose(page : ContentFile, navigation : Navigation? = nil) : String
      content_html = converter.convert(page)
      content_html = converter.add_heading_ids(content_html)
      toc = converter.extract_toc(content_html)

      nav_html = navigation ? render_nav(navigation) : ""
      toc_html = render_toc(toc)
      breadcrumbs_html = navigation ? render_breadcrumbs(navigation, page) : ""
      prev_next_html = navigation ? render_prev_next(navigation, page) : ""
      component_selector_html = render_component_selector

      page_title = extract_title(content_html) || page.basename.sub(/\.adoc\z/, "")

      render_layout(
        site_title: playbook.site.title,
        page_title: page_title,
        nav_html: nav_html,
        toc_html: toc_html,
        breadcrumbs_html: breadcrumbs_html,
        content_html: content_html,
        prev_next_html: prev_next_html,
        component_selector_html: component_selector_html,
        livereload: playbook.server.livereload
      )
    end

    private def extract_title(html : String) : String?
      if match = html.match(/<h1[^>]*>([^<]+)<\/h1>/)
        match[1]
      end
    end

    private def render_nav(navigation : Navigation) : String
      String.build do |str|
        str << %(<nav class="nav-menu">\n)
        render_nav_items(str, navigation.items, 0)
        str << %(</nav>\n)
      end
    end

    private def render_nav_items(str : String::Builder, items : Array(NavItem), depth : Int32)
      return if items.empty?
      str << %(<ul class="nav-list nav-depth-#{depth}">\n)
      items.each do |item|
        has_children = !item.children.empty?
        str << %(<li class="nav-item#{has_children ? " has-children" : ""}">\n)
        if item.url.empty?
          str << %(<span class="nav-text">#{HTML.escape(item.title)}</span>\n)
        else
          url = item.url.sub(/\.adoc\z/, ".html")
          str << %(<a class="nav-link" href="#{url}">#{HTML.escape(item.title)}</a>\n)
        end
        render_nav_items(str, item.children, depth + 1) if has_children
        str << %(</li>\n)
      end
      str << %(</ul>\n)
    end

    private def render_toc(toc : Array({level: Int32, id: String, title: String})) : String
      return "" if toc.empty?

      String.build do |str|
        str << %(<aside class="toc">\n)
        str << %(<h3 class="toc-title">On this page</h3>\n)
        str << %(<ul class="toc-list">\n)
        toc.each do |entry|
          indent = entry[:level] - 2
          str << %(<li class="toc-item toc-level-#{indent}">)
          str << %(<a href="##{entry[:id]}">#{HTML.escape(entry[:title])}</a>)
          str << %(</li>\n)
        end
        str << %(</ul>\n)
        str << %(</aside>\n)
      end
    end

    private def render_breadcrumbs(navigation : Navigation, page : ContentFile) : String
      page_url = page.basename.sub(/\.adoc\z/, ".html")
      crumbs = navigation.find_breadcrumbs(page.basename)
      return "" if crumbs.empty?

      String.build do |str|
        str << %(<nav class="breadcrumbs">\n)
        str << %(<ul>\n)
        crumbs.each_with_index do |crumb, i|
          if i == crumbs.size - 1
            str << %(<li class="current">#{HTML.escape(crumb.title)}</li>\n)
          else
            url = crumb.url.empty? ? "#" : crumb.url.sub(/\.adoc\z/, ".html")
            str << %(<li><a href="#{url}">#{HTML.escape(crumb.title)}</a></li>\n)
          end
        end
        str << %(</ul>\n)
        str << %(</nav>\n)
      end
    end

    private def render_prev_next(navigation : Navigation, page : ContentFile) : String
      prev_item, next_item = navigation.find_prev_next(page.basename)
      return "" unless prev_item || next_item

      String.build do |str|
        str << %(<nav class="prev-next">\n)
        if pi = prev_item
          url = pi.url.sub(/\.adoc\z/, ".html")
          str << %(<a class="prev" href="#{url}">&larr; #{HTML.escape(pi.title)}</a>\n)
        else
          str << %(<span class="prev"></span>\n)
        end
        if ni = next_item
          url = ni.url.sub(/\.adoc\z/, ".html")
          str << %(<a class="next" href="#{url}">#{HTML.escape(ni.title)} &rarr;</a>\n)
        else
          str << %(<span class="next"></span>\n)
        end
        str << %(</nav>\n)
      end
    end

    private def render_component_selector : String
      return "" if catalog.components.size <= 1

      String.build do |str|
        str << %(<div class="component-selector">\n)
        str << %(<select onchange="window.location.href=this.value">\n)
        catalog.components.each do |comp|
          str << %(<option value="/#{comp.url_segment}/">#{HTML.escape(comp.title)}</option>\n)
        end
        str << %(</select>\n)
        str << %(</div>\n)
      end
    end

    private def render_layout(
      site_title : String,
      page_title : String,
      nav_html : String,
      toc_html : String,
      breadcrumbs_html : String,
      content_html : String,
      prev_next_html : String,
      component_selector_html : String,
      livereload : Bool
    ) : String
      livereload_script = if livereload
                            <<-JS
                            <script>
                            (function() {
                              var lastUpdate = '';
                              setInterval(function() {
                                fetch('/_/livereload')
                                  .then(function(r) { return r.text(); })
                                  .then(function(t) {
                                    if (lastUpdate && lastUpdate !== t) {
                                      window.location.reload();
                                    }
                                    lastUpdate = t;
                                  })
                                  .catch(function() {});
                              }, 2000);
                            })();
                            </script>
                            JS
                          else
                            ""
                          end

      <<-HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{HTML.escape(page_title)} | #{HTML.escape(site_title)}</title>
        <style>
      #{Theme::CSS}
        </style>
      </head>
      <body>
        <header class="site-header">
          <div class="header-inner">
            <a class="site-title" href="/">#{HTML.escape(site_title)}</a>
            #{component_selector_html}
            <div class="search-placeholder">
              <input type="text" placeholder="Search docs..." disabled>
            </div>
          </div>
        </header>
        <div class="main-wrapper">
          <aside class="sidebar">
            #{nav_html}
          </aside>
          <main class="content">
            #{breadcrumbs_html}
            <article class="doc">
              #{content_html}
            </article>
            #{prev_next_html}
          </main>
          #{toc_html}
        </div>
        <footer class="site-footer">
          <p>Built with <a href="https://github.com/aloli-crystal/crystal-antora">Crystal Antora</a></p>
        </footer>
        #{livereload_script}
      </body>
      </html>
      HTML
    end
  end
end

require "html"
