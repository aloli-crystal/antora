require "yaml"
require "json"
require "http/server"
require "file_utils"

require "./antora/playbook"
require "./antora/component"
require "./antora/classifier"
require "./antora/navigation"
require "./antora/content_aggregator"
require "./antora/converter"
require "./antora/page_composer"
require "./antora/site_publisher"
require "./antora/theme"
require "./antora/auth/auth_middleware"
require "./antora/auth/saml"
require "./antora/dev_server"

module Antora
  # Lue au compile-time depuis `shard.yml` via le macro `read_file`.
  # Cf. note mémoire `feedback_shard_version_macro.md` (mémoire ALOLI).
  VERSION = {{
              (read_file("#{__DIR__}/../shard.yml")
                .lines
                .find(&.starts_with?("version:")) || "version: 0.0.0")
                .gsub(/^version:\s*/, "")
                .chomp
            }}
end
