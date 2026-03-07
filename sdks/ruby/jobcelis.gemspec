Gem::Specification.new do |s|
  s.name        = "jobcelis"
  s.version     = "1.0.0"
  s.summary     = "Official Ruby SDK for the Jobcelis Event Infrastructure Platform"
  s.description = "Ruby client for the Jobcelis API — events, webhooks, jobs, pipelines, and more. Connects to https://jobcelis.com by default."
  s.authors     = ["Jobcelis"]
  s.email       = "vladiceli6@gmail.com"
  s.homepage    = "https://jobcelis.com"
  s.license     = "MIT"
  s.files       = Dir["lib/**/*.rb"] + ["README.md", "LICENSE"]
  s.required_ruby_version = ">= 3.0"
  s.add_dependency "net-http"
  s.metadata = {
    "homepage_uri" => "https://jobcelis.com",
    "source_code_uri" => "https://github.com/vladimirCeli/jobcelis-ruby",
    "documentation_uri" => "https://jobcelis.com/docs"
  }
end
