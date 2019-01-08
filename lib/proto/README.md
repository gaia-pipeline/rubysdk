# How to generate gRPC server interfaces
If the `plugin.proto` file has been changed, it's sometimes useful to regenerate the gRPC server interfaces.
You can use the command `grpc_tools_ruby_protoc -I . --ruby_out=. --grpc_out=. plugin.proto` automatically regenerate them. Note that the gem `grpc` and `grpc-tools` needs to be installed.
