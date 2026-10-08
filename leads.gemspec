require_relative "lib/leads/version"

# The gemspec's name is the plugin's key and its table prefix.
Gem::Specification.new do |spec|
  spec.name = "leads"
  spec.version = Leads::VERSION
  spec.summary = "Leads for Runwell: capture, scoring, follow-ups and email sequences, until a lead becomes a client"
  spec.authors = [ "Martin Business Consultants" ]
  spec.homepage = "https://github.com/Martin-Business-Consultants/runwell-leads"
  spec.license = "FSL-1.1-MIT"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
