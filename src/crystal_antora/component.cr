require "yaml"

module CrystalAntora
  class Component
    property name : String
    property title : String
    property version : String
    property nav : Array(String)
    property base_path : String

    def initialize(
      @name = "",
      @title = "",
      @version = "",
      @nav = [] of String,
      @base_path = ""
    )
    end

    def self.load(path : String) : Component
      data = YAML.parse(File.read(path))
      from_yaml(data, File.dirname(path))
    end

    def self.from_yaml(data : YAML::Any, base_path : String = ".") : Component
      component = Component.new
      component.base_path = base_path
      component.name = data["name"]?.try(&.as_s) || ""
      component.title = data["title"]?.try(&.as_s) || component.name
      component.version = data["version"]?.try(&.as_s) || ""
      if nav_data = data["nav"]?
        component.nav = nav_data.as_a.map(&.as_s)
      end
      component
    end

    def url_segment : String
      version.empty? ? name : "#{name}/#{version}"
    end
  end
end
