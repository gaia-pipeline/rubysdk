#!/usr/bin/env ruby

this_dir = File.expand_path(File.dirname(__FILE__))
proto_dir = File.join(this_dir, 'proto')
interface_dir = File.join(this_dir, 'interface')
$LOAD_PATH.unshift(proto_dir) unless $LOAD_PATH.include?(proto_dir)
$LOAD_PATH.unshift(interface_dir) unless $LOAD_PATH.include?(interface_dir)

require 'grpc'
require 'plugin_services_pb'
require 'interface'

# GRPCServer provides an implementation of the Plugin service.
class GRPCServer < Proto::Plugin::Service
  def initialize(cached_jobs)
    @cached_jobs = cached_jobs
  end

  def GetJobs(empty)
    @cached_jobs.each { |job| yield job.job }
  end

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
      job.handler(args)
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

def Serve()
  job1 = Job.new
  job2 = Job.new
  cached_jobs = [job1, job2]
  port = '0.0.0.0:50051'
  s = GRPC::RpcServer.new
  s.add_http2_port(port, :this_port_is_insecure)
  puts "GRPC Server started on port #{port}"
  s.handle(GRPCServer.new(cached_jobs))
  s.run_till_terminated
end

Serve()

