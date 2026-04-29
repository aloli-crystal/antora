module Antora
  class Converter
    property catalog : ContentCatalog

    def initialize(@catalog : ContentCatalog)
    end

    def convert(page : ContentFile) : String
      content = File.read(page.path)
      content = resolve_includes(content, page)
      html = asciidoc_to_html(content)
      html = resolve_xrefs(html, page)
      html = resolve_images(html, page)
      html
    end

    private def asciidoc_to_html(content : String) : String
      html = String.build do |str|
        in_paragraph = false
        in_code_block = false
        code_language = ""
        code_buffer = String::Builder.new
        in_list = false
        list_depth = 0

        content.each_line do |line|
          stripped = line.strip

          if stripped.starts_with?("[source")
            if match = stripped.match(/\[source,\s*(\w+)\]/)
              code_language = match[1]
            else
              code_language = ""
            end
            next
          end

          if stripped == "----"
            if in_code_block
              lang_attr = code_language.empty? ? "" : %( class="language-#{code_language}")
              str << "<pre><code#{lang_attr}>"
              str << HTML.escape(code_buffer.to_s.chomp)
              str << "</code></pre>\n"
              code_buffer = String::Builder.new
              code_language = ""
              in_code_block = false
            else
              in_code_block = true
            end
            next
          end

          if in_code_block
            code_buffer << line << "\n"
            next
          end

          if stripped.empty?
            if in_paragraph
              str << "</p>\n"
              in_paragraph = false
            end
            if in_list
              list_depth.times { str << "</ul>\n" }
              in_list = false
              list_depth = 0
            end
            next
          end

          if stripped.starts_with?("= ") && !stripped.starts_with?("== ")
            close_paragraph(str, in_paragraph)
            in_paragraph = false
            str << "<h1>" << HTML.escape(stripped[2..]) << "</h1>\n"
          elsif stripped.starts_with?("== ")
            close_paragraph(str, in_paragraph)
            in_paragraph = false
            str << "<h2>" << HTML.escape(stripped[3..]) << "</h2>\n"
          elsif stripped.starts_with?("=== ")
            close_paragraph(str, in_paragraph)
            in_paragraph = false
            str << "<h3>" << HTML.escape(stripped[4..]) << "</h3>\n"
          elsif stripped.starts_with?("==== ")
            close_paragraph(str, in_paragraph)
            in_paragraph = false
            str << "<h4>" << HTML.escape(stripped[5..]) << "</h4>\n"
          elsif stripped.starts_with?("* ") || stripped.starts_with?("** ")
            close_paragraph(str, in_paragraph)
            in_paragraph = false
            depth = 0
            pos = 0
            while pos < stripped.size && stripped[pos] == '*'
              depth += 1
              pos += 1
            end
            text = stripped[pos..].strip

            if !in_list
              in_list = true
              list_depth = depth
              depth.times { str << "<ul>\n" }
            elsif depth > list_depth
              (depth - list_depth).times { str << "<ul>\n" }
              list_depth = depth
            elsif depth < list_depth
              (list_depth - depth).times { str << "</ul>\n" }
              list_depth = depth
            end
            str << "<li>" << process_inline(text) << "</li>\n"
          elsif stripped.starts_with?("image::")
            close_paragraph(str, in_paragraph)
            in_paragraph = false
            if match = stripped.match(/image::([^\[]+)\[([^\]]*)\]/)
              src = match[1]
              alt = match[2]
              str << %(<div class="imageblock"><img src=") << src << %(" alt=") << HTML.escape(alt) << %("></div>\n)
            end
          else
            unless in_paragraph
              str << "<p>"
              in_paragraph = true
            else
              str << " "
            end
            str << process_inline(stripped)
          end
        end

        if in_paragraph
          str << "</p>\n"
        end
        if in_list
          list_depth.times { str << "</ul>\n" }
        end
      end

      html
    end

    private def close_paragraph(str : String::Builder, in_paragraph : Bool)
      str << "</p>\n" if in_paragraph
    end

    private def process_inline(text : String) : String
      result = HTML.escape(text)
      result = result.gsub(/\*\*([^*]+)\*\*/) { "<strong>#{$1}</strong>" }
      result = result.gsub(/\*([^*]+)\*/) { "<strong>#{$1}</strong>" }
      result = result.gsub(/_([^_]+)_/) { "<em>#{$1}</em>" }
      result = result.gsub(/`([^`]+)`/) { "<code>#{$1}</code>" }
      result = result.gsub(/xref:([^\[]+)\[([^\]]*)\]/) { %(<a href="#{$1}">#{$2}</a>) }
      result = result.gsub(/link:([^\[]+)\[([^\]]*)\]/) { %(<a href="#{$1}">#{$2}</a>) }
      result
    end

    private def resolve_includes(content : String, page : ContentFile) : String
      content.gsub(/^include::([^\[]+)\[([^\]]*)\]/m) do |match|
        target = $1
        _attrs = $2
        resolve_include_target(target, page)
      end
    end

    private def resolve_include_target(target : String, page : ContentFile) : String
      page_dir = File.dirname(page.path)

      candidates = [
        File.join(page_dir, target),
        File.join(page_dir, "..", "partials", target),
        File.join(page_dir, "..", "examples", target),
      ]

      candidates.each do |candidate|
        path = File.expand_path(candidate)
        if File.exists?(path)
          return File.read(path)
        end
      end

      catalog.partials.each do |partial|
        if partial.basename == File.basename(target) || partial.relative_path == target
          return File.read(partial.path) if File.exists?(partial.path)
        end
      end

      catalog.examples.each do |example|
        if example.basename == File.basename(target) || example.relative_path == target
          return File.read(example.path) if File.exists?(example.path)
        end
      end

      "<!-- include not found: #{target} -->"
    end

    private def resolve_xrefs(html : String, page : ContentFile) : String
      html.gsub(/href="([^"]+\.adoc)"/) do
        href = $1
        resolved = href.sub(/\.adoc\z/, ".html")
        %(href="#{resolved}")
      end
    end

    private def resolve_images(html : String, page : ContentFile) : String
      html.gsub(/src="([^"]*)"/) do
        src = $1
        if src.starts_with?("http://") || src.starts_with?("https://")
          %(src="#{src}")
        else
          component = page.component_name
          mod = page.module_name
          %(src="/_/img/#{component}/#{mod}/#{src}")
        end
      end
    end

    def extract_toc(html : String) : Array({level: Int32, id: String, title: String})
      toc = [] of {level: Int32, id: String, title: String}
      html.scan(/<h([2-4])[^>]*>([^<]+)<\/h\1>/) do |match|
        level = match[1].to_i
        title = match[2]
        id = title.downcase.gsub(/[^\w]+/, "-").strip("-")
        toc << {level: level, id: id, title: title}
      end
      toc
    end

    def add_heading_ids(html : String) : String
      html.gsub(/<h([2-4])>([^<]+)<\/h\1>/) do
        level = $1
        title = $2
        id = title.downcase.gsub(/[^\w]+/, "-").strip("-")
        %(<h#{level} id="#{id}">#{title}</h#{level}>)
      end
    end
  end
end

require "html"
