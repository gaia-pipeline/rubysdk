#!/usr/bin/env ruby

this_dir = File.expand_path(File.dirname(__FILE__))
proto_dir = File.join(this_dir, 'proto')
interface_dir = File.join(this_dir, 'interface')
$LOAD_PATH.unshift(proto_dir) unless $LOAD_PATH.include?(proto_dir)
$LOAD_PATH.unshift(interface_dir) unless $LOAD_PATH.include?(interface_dir)

require 'grpc'
require 'fnv'
require 'plugin_services_pb'
require 'interface'

# GRPCServer provides an implementation of the Plugin service.
class GRPCServer < Proto::Plugin::Service
  def initialize(cached_jobs)
    @cached_jobs = cached_jobs
  end

  # GetJobs returns all registered jobs.
  def GetJobs(empty)
    @cached_jobs.each { |job| yield job.job }
  end

  # ExecuteJob executes the given job and returns a result.
  def ExecuteJob(job)
    cjob = nil
    @cached_jobs.each do |cached_job|
      cjob = cached_job unless cached_job.unique_id == job.unique_id
    end
    if cjob == nil
      JobResult.new(failed: true,
                    exit_pipeline: true,
                    message: "job not found in plugin " + job.title)
      return
    end

    # Transform arguments
    args = []
    job.args.each do |arg|
      new_arg = Proto::Argument.new(key: arg.key,
                             value: arg.value)
      args.push new_arg
    end

    # Execute job
    job_result = JobResult.new
    begin
      job.handler.call(args)
    rescue => e
      # Check if job wants to force exit pipeline.
      # We will exit the pipeline but not mark it as 'failed'.
      job_result.failed = true unless e == ErrorExitPipeline

      # Set log message and job id
      job_result.exit_pipeline = true
      job_result.message = e.message
      job_result.unique_id = job.job.unique_id
    end
  end
end

# Serve caches the given jobs and starts the gRPC server.
# This function should be last called in the plugin main function.
def Serve(jobs)
  include Interface

  # Cache the jobs for later processing.
  # We have to transform given jobs into suitable proto models.
  cached_jobs = []
  jobs.each do |job|
    # Transform manual interaction
    manual_interaction = nil
    if job.interaction != nil
      manual_interaction = ManualInteraction.new(description: job.interaction.desc,
                                                 type: job.interaction.type,
                                                 value: job.interaction.value)
    end

    # Transform arguments
    args = []
    if job.args != nil
      job.args.each do |arg|
        trans_arg = Proto::Argument.new(description: arg.desc,
                                        type: arg.type,
                                        key: arg.key,
                                        value: arg.value)

        args.push trans_arg
      end
    end

    # Create proto job object
    proto_job = Proto::Job.new(unique_id: FNV.new.fnv1a_32(job.title),
                               title: job.title,
                               description: job.title,
                               args: args,
                               interaction: manual_interaction)

    # Resolve job dependencies
    if job.dependson != nil
      proto_job.dependson = Google::Protobuf::RepeatedField.new(:uint32, [])
      job.dependson.each do |dep_job|
        dep_found = false
        jobs.each do |curr_job|
          if curr_job.title.casecmp(dep_job) == 0
            proto_job.dependson += FNV.new.fnv1a_32(curr_job.title)
            dep_found = true
            break
          end
        end
        
        raise "job #{job.title} has dependency #{dep_job} which is not declared" unless dep_found == true
      end
    end

    # Create wrapper object
    wrapper_job = JobsWrapper.new(handler: job.handler,
                                  job: proto_job)
    cached_jobs.push wrapper_job
  end

  # Check if two jobs have the same title which is restricted.
  #dup_map = {}
  cached_jobs.each do |job|
    #dup_map[job.job.unique_id] = (map[job.job.unique_id] || 0) + 1

    #if dup_map[job.job.unique_id] > 1
    #  raise "duplicate job with the title #{job.title} found which is not allowed"
    #end
  end

  # Get certificates path from env variables.
  cert_path = ENV["GAIA_PLUGIN_CERT"]
  key_path = ENV["GAIA_PLUGIN_KEY"]
  root_ca_path = ENV["GAIA_PLUGIN_CA_CERT"]

  # Check if all certs are available.
  raise "cannot find path to certificate" unless File.file?(cert_path)
  raise "cannot find path to key" unless File.file?(key_path)
  raise "cannot find path to root CA certificate" unless File.file?(root_ca_path)

  # Implement health service.
  #health_svc = GRPC::Health::Checker.new
  #health_svc.add_status("plugin", GRPC::Core::StatusCodes::SERVING)

  # Load certificates and create credentials.
  credentials = GRPC::Core::ServerCredentials.new(
    File.read(root_ca_path),
    [{
      private_key: File.read(key_path),
      cert_chain: File.read(cert_path)
    }],
    true # force client authentication.
  )

  # Register gRPC server and handle.
  host = 'localhost'
  s = GRPC::RpcServer.new
  port = s.add_http2_port(host+':0', credentials)
  s.handle(GRPCServer.new(cached_jobs))

  # Output the address and service name to stdout.
  # hashicorp go-plugin will use that to establish a connection.
  puts "1|2|tcp|#{host}:#{port}|grpc"
  STDOUT.sync = true

  s.run_till_terminated
end

