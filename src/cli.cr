require "option_parser"
require "./antora"

# Point d'entrée CLI du binaire `antora`. Le module `Antora` peut
# toujours être chargé en bibliothèque via `require "antora"` ; ce
# fichier n'est exécuté que quand le binaire `antora` est invoqué
# (target dans `shard.yml`).
#
# Pour l'instant le CLI se limite à `--help` et `--version`. Le
# démarrage du serveur (DevServer + playbook) sera branché ici dans
# une version ultérieure quand l'API CLI sera stable (cf. roadmap).

playbook_path : String? = nil

parser = OptionParser.new do |p|
  p.banner = <<-BANNER
    Usage : antora [options] [PLAYBOOK]

    Statique site generator pour la documentation Crystal, inspiré
    de l'outil https://antora.org/[Antora] de la communauté Asciidoctor.

    Sans PLAYBOOK, imprime cette aide. Avec PLAYBOOK (chemin vers un
    `antora-playbook.yml`), démarrera (à terme) le DevServer ; pour
    l'instant cette fonctionnalité est en cours d'intégration.

    Variables d'environnement reconnues (futur) :
      ANTORA_HOST     adresse d'écoute du DevServer (défaut : 127.0.0.1)
      ANTORA_PORT     port du DevServer (défaut : 3000)
      ANTORA_LOG      niveau de log : debug | info | warn | error

    Options :
    BANNER

  p.on("-v", "--version", "Affiche la version") do
    puts "antora #{Antora::VERSION}"
    exit 0
  end
  p.on("-h", "--help", "Affiche cette aide") do
    puts p
    exit 0
  end

  p.invalid_option do |flag|
    STDERR.puts "Option inconnue : #{flag}"
    STDERR.puts p
    exit 1
  end
end

positional = [] of String
parser.unknown_args { |args| positional = args }
parser.parse(ARGV)

# Sans argument positionnel, on imprime l'aide globale (UX standard
# pour un CLI qui ne fait rien sans input).
if positional.empty?
  puts parser
  exit 0
end

playbook_path = positional.first

# Garde-fou tant que le runner DevServer n'est pas branché : on
# imprime un message clair plutôt que de planter silencieusement.
unless File.exists?(playbook_path)
  STDERR.puts "Erreur : playbook introuvable : #{playbook_path}"
  exit 1
end

STDERR.puts "TODO : démarrer le DevServer avec #{playbook_path}"
STDERR.puts "Cette fonctionnalité est en cours d'intégration ; pour"
STDERR.puts "l'instant utilisez l'API directement :"
STDERR.puts "  playbook  = Antora::Playbook.from_file(\"#{playbook_path}\")"
STDERR.puts "  catalog   = Antora::ContentAggregator.new(playbook).aggregate"
STDERR.puts "  composer  = Antora::PageComposer.new(playbook)"
STDERR.puts "  Antora::DevServer.new(playbook, catalog, composer, …).start"
exit 0
