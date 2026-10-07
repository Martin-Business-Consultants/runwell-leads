# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "leads"
  spec.version = "1.0.0"
  spec.summary = "Lead nurturing for the CMS: leads from form submissions, scoring, tasks and email sequences"
  spec.authors = ["Martin Business Consultants"]
  spec.homepage = "https://github.com/Martin-Business-Consultants/cms-leads"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.required_ruby_version = ">= 3.3"
  spec.add_dependency "rails", ">= 8.1"
end
