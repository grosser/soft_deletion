$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
name = "soft_deletion"
require "#{name}/version"

Gem::Specification.new name, SoftDeletion::VERSION do |s|
  s.summary = "Explicit soft deletion for ActiveRecord via deleted_at and default scope."
  s.authors = ["Zendesk"]
  s.email = "michael@grosser.it"
  s.homepage = "https://github.com/grosser/#{name}"
  s.files = `git ls-files`.split("\n")
  s.license = "MIT"
  key = File.expand_path("~/.ssh/gem-private_key.pem")
  if File.exist?(key)
    s.signing_key = key
    s.cert_chain = ["gem-public_cert.pem"]
  end
end
