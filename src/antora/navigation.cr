module Antora
  class NavItem
    property title : String
    property url : String
    property children : Array(NavItem)

    def initialize(@title = "", @url = "", @children = [] of NavItem)
    end

    def leaf? : Bool
      children.empty?
    end
  end

  class Navigation
    property items : Array(NavItem)

    def initialize(@items = [] of NavItem)
    end

    def self.parse(content : String) : Navigation
      items = [] of NavItem
      stack = [{level: 0, items: items}]

      content.each_line do |line|
        stripped = line.strip
        next if stripped.empty?
        next unless stripped.starts_with?("*")

        level = 0
        pos = 0
        while pos < stripped.size && stripped[pos] == '*'
          level += 1
          pos += 1
        end

        text = stripped[pos..].strip
        title, url = parse_xref(text)

        item = NavItem.new(title: title, url: url)

        while stack.size > 1 && stack.last[:level] >= level
          stack.pop
        end

        stack.last[:items] << item
        stack.push({level: level, items: item.children})
      end

      Navigation.new(items)
    end

    def self.parse_xref(text : String) : {String, String}
      if match = text.match(/xref:([^\[]+)\[([^\]]*)\]/)
        url = match[1]
        title = match[2]
        title = url if title.empty?
        {title, url}
      else
        clean = text.gsub(/^\*+\s*/, "")
        {clean, ""}
      end
    end

    def flat_pages : Array(NavItem)
      result = [] of NavItem
      collect_pages(items, result)
      result
    end

    private def collect_pages(items : Array(NavItem), result : Array(NavItem))
      items.each do |item|
        result << item unless item.url.empty?
        collect_pages(item.children, result)
      end
    end

    def find_prev_next(current_url : String) : {NavItem?, NavItem?}
      pages = flat_pages
      idx = pages.index { |p| p.url == current_url }
      return {nil, nil} unless idx

      prev_item = idx > 0 ? pages[idx - 1] : nil
      next_item = idx < pages.size - 1 ? pages[idx + 1] : nil
      {prev_item, next_item}
    end

    def find_breadcrumbs(target_url : String) : Array(NavItem)
      result = [] of NavItem
      find_breadcrumbs_recursive(items, target_url, result)
      result
    end

    private def find_breadcrumbs_recursive(items : Array(NavItem), target_url : String, path : Array(NavItem)) : Bool
      items.each do |item|
        path << item
        return true if item.url == target_url
        return true if find_breadcrumbs_recursive(item.children, target_url, path)
        path.pop
      end
      false
    end
  end
end
