module CrystalAntora
  class ContentCatalog
    property components : Array(Component)
    property files : Array(ContentFile)
    property navigations : Hash(String, Navigation)

    def initialize(
      @components = [] of Component,
      @files = [] of ContentFile,
      @navigations = {} of String => Navigation,
    )
    end

    def pages : Array(ContentFile)
      files.select { |f| f.family == FileFamily::Page }
    end

    def partials : Array(ContentFile)
      files.select { |f| f.family == FileFamily::Partial }
    end

    def images : Array(ContentFile)
      files.select { |f| f.family == FileFamily::Image }
    end

    def attachments : Array(ContentFile)
      files.select { |f| f.family == FileFamily::Attachment }
    end

    def examples : Array(ContentFile)
      files.select { |f| f.family == FileFamily::Example }
    end

    def find_page(component : String, mod : String, page : String) : ContentFile?
      pages.find do |f|
        f.component_name == component &&
          f.module_name == mod &&
          (f.basename == page || f.relative_path == page)
      end
    end
  end

  class ContentAggregator
    property playbook : Playbook

    def initialize(@playbook : Playbook)
    end

    def aggregate : ContentCatalog
      catalog = ContentCatalog.new

      playbook.content_sources.each do |source|
        scan_source(source, catalog)
      end

      catalog
    end

    private def scan_source(source : Playbook::ContentSource, catalog : ContentCatalog)
      base_path = source.url
      start_path = source.start_path

      root = if start_path == "."
               base_path
             else
               File.join(base_path, start_path)
             end

      return unless Dir.exists?(root)

      antora_yml = File.join(root, "antora.yml")
      if File.exists?(antora_yml)
        component = Component.load(antora_yml)
        catalog.components << component
        scan_component(root, component, catalog)
      end
    end

    private def scan_component(root : String, component : Component, catalog : ContentCatalog)
      modules_dir = File.join(root, "modules")
      return unless Dir.exists?(modules_dir)

      Dir.each_child(modules_dir) do |mod_name|
        mod_path = File.join(modules_dir, mod_name)
        next unless File.directory?(mod_path)
        scan_module(mod_path, mod_name, component, catalog)
      end

      component.nav.each do |nav_path|
        full_nav = File.join(root, nav_path)
        if File.exists?(full_nav)
          nav = Navigation.parse(File.read(full_nav))
          key = "#{component.name}:#{nav_path}"
          catalog.navigations[key] = nav
        end
      end
    end

    private def scan_module(mod_path : String, mod_name : String, component : Component, catalog : ContentCatalog)
      Classifier::FAMILY_DIRS.each_key do |family_dir|
        dir = File.join(mod_path, family_dir)
        next unless Dir.exists?(dir)
        scan_directory(dir, component.name, mod_name, catalog)
      end
    end

    private def scan_directory(dir : String, component_name : String, mod_name : String, catalog : ContentCatalog)
      Dir.glob(File.join(dir, "**", "*")).each do |file_path|
        next if File.directory?(file_path)
        content_file = Classifier.classify(file_path, component_name, "")
        content_file.module_name = mod_name
        catalog.files << content_file
      end
    end
  end
end
