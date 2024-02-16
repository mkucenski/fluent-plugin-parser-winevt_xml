lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name    = "fluent-plugin-winevtx-xml-nxt"
  spec.version = "1.0"
  spec.authors = "Matt K."
  spec.email   = ""

  spec.summary       = "Next-Gen Fluentd parser plugin to parse XML rendered windows event log."
  spec.description   = "Next-Gen Fluentd parser plugin to parse XML rendered windows event log."
  spec.homepage      = "https://github.com/mkucenski/fluent-plugin-parser-winevt_xml"
  spec.license       = "Apache-2.0"

  test_files, files  = `git ls-files -z`.split("\x0").partition do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.files         = files
  spec.executables   = files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = test_files
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.5.6"
  spec.add_development_dependency "rake", "~> 13.1.0"
  spec.add_development_dependency "test-unit", "~> 3.5.7"
  spec.add_runtime_dependency "fluentd", [">= 0.14.10", "< 2"]
  spec.add_runtime_dependency "nokogiri", [">= 1.12.5", "< 1.16"]
end
