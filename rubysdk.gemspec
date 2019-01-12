Gem::Specification.new do |s|
  s.name        = 'rubysdk'
  s.version     = '0.0.1.pre2'
  s.date        = '2019-01-08'
  s.licenses    = ['Apache-2.0']
  s.summary     = "Ruby SDK for Gaia pipelines (https://gaia-pipeline.io)."
  s.authors     = ["Michel Vocks"]
  s.email       = 'michelvocks@gmail.com'
  s.homepage    = 'https://gaia-pipeline.io'
  s.files       = ["lib/rubysdk.rb", "lib/interface/interface.rb", "lib/proto/plugin_pb.rb", "lib/proto/plugin_services_pb.rb"]
  s.add_runtime_dependency "grpc", ["~> 1.17"]
  s.add_runtime_dependency "fnv", ["~> 0.2"]
  s.add_development_dependency "grpc-tools", ["~> 1.17"]
end
