module Antora
  enum FileFamily
    Page
    Partial
    Image
    Attachment
    Example
  end

  class ContentFile
    property path : String
    property family : FileFamily
    property module_name : String
    property component_name : String
    property relative_path : String

    def initialize(
      @path = "",
      @family = FileFamily::Page,
      @module_name = "ROOT",
      @component_name = "",
      @relative_path = "",
    )
    end

    def basename : String
      File.basename(@path)
    end

    def extension : String
      File.extname(@path)
    end
  end

  class Classifier
    FAMILY_DIRS = {
      "pages"       => FileFamily::Page,
      "partials"    => FileFamily::Partial,
      "images"      => FileFamily::Image,
      "attachments" => FileFamily::Attachment,
      "examples"    => FileFamily::Example,
    }

    def self.classify(file_path : String, component_name : String = "", module_base : String = "") : ContentFile
      family = FileFamily::Page
      relative = file_path

      FAMILY_DIRS.each do |dir_name, file_family|
        pattern = "/#{dir_name}/"
        if file_path.includes?(pattern)
          family = file_family
          idx = file_path.index(pattern)
          if idx
            relative = file_path[(idx + dir_name.size + 2)..]
          end
          break
        end
      end

      module_name = extract_module_name(file_path, module_base)

      ContentFile.new(
        path: file_path,
        family: family,
        module_name: module_name,
        component_name: component_name,
        relative_path: relative
      )
    end

    def self.extract_module_name(file_path : String, module_base : String = "") : String
      modules_pattern = "/modules/"
      if (idx = file_path.index(modules_pattern))
        after_modules = file_path[(idx + modules_pattern.size)..]
        slash_idx = after_modules.index('/')
        if slash_idx
          return after_modules[0...slash_idx]
        end
      end
      "ROOT"
    end

    def self.family_for_directory(dir_name : String) : FileFamily?
      FAMILY_DIRS[dir_name]?
    end
  end
end
