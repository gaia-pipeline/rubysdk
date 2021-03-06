# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: plugin.proto

require 'google/protobuf'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "proto.Job" do
    optional :unique_id, :uint32, 1
    optional :title, :string, 2
    optional :description, :string, 3
    repeated :dependson, :uint32, 4
    repeated :args, :message, 5, "proto.Argument"
    optional :interaction, :message, 6, "proto.ManualInteraction"
  end
  add_message "proto.Argument" do
    optional :description, :string, 1
    optional :type, :string, 2
    optional :key, :string, 3
    optional :value, :string, 4
  end
  add_message "proto.ManualInteraction" do
    optional :description, :string, 1
    optional :type, :string, 2
    optional :value, :string, 3
  end
  add_message "proto.JobResult" do
    optional :unique_id, :uint32, 1
    optional :failed, :bool, 2
    optional :exit_pipeline, :bool, 3
    optional :message, :string, 4
  end
  add_message "proto.Empty" do
  end
end

module Proto
  Job = Google::Protobuf::DescriptorPool.generated_pool.lookup("proto.Job").msgclass
  Argument = Google::Protobuf::DescriptorPool.generated_pool.lookup("proto.Argument").msgclass
  ManualInteraction = Google::Protobuf::DescriptorPool.generated_pool.lookup("proto.ManualInteraction").msgclass
  JobResult = Google::Protobuf::DescriptorPool.generated_pool.lookup("proto.JobResult").msgclass
  Empty = Google::Protobuf::DescriptorPool.generated_pool.lookup("proto.Empty").msgclass
end
