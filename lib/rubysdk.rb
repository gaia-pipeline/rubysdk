this_dir = File.expand_path(File.dirname(__FILE__))
proto_dir = File.join(this_dir, 'proto')
interface_dir = File.join(this_dir, 'interface')
$LOAD_PATH.unshift(proto_dir) unless $LOAD_PATH.include?(proto_dir)
$LOAD_PATH.unshift(interface_dir) unless $LOAD_PATH.include?(interface_dir)
STDOUT.sync = true

require 'grpc'
require 'grpc/health/checker'
require 'fnv'
require 'plugin_services_pb'
require 'interface'

module RubySDK
  # GRPCServer provides an implementation of the Plugin service.
  class GRPCServer < Proto::Plugin::Service
    def initialize(cached_jobs)
      @cached_jobs = cached_jobs
    end

    # get_jobs returns all registered jobs.
    def get_jobs(empty, _call)
      jobs = []
      @cached_jobs.each { |job| jobs.push job.job }
      jobs.each
    end

    # execute_job executes the given job and returns a result.
    def execute_job(job, _call)
      cjob = nil
      @cached_jobs.each do |cached_job|
        cjob = cached_job if cached_job.job.unique_id == job.unique_id
      end
      if cjob == nil
        Proto::JobResult.new(failed: true,
                      exit_pipeline: true,
                      message: "job not found in plugin " + job.title)
        return
      end

      # Transform arguments
      args = []
      if !job.args.empty?
        job.args.each do |arg|
          new_arg = Proto::Argument.new(key: arg.key,
                               value: arg.value)
          args.push new_arg
        end
      end

      # Execute job
      job_failed = false
      exit_pipeline = false
      message = ""
      unique_id = 0
      begin
        cjob.handler.call(args)
      rescue => e
        # Check if job wants to force exit pipeline.
        # We will exit the pipeline but not mark it as 'failed'.
        job_failed = true if e == ErrorExitPipeline

        # Set log message and job id
        exit_pipeline = true
        message = e.message
        unique_id = job.job.unique_id
      end
      Proto::JobResult.new(unique_id: unique_id,
                           failed: job_failed,
                           exit_pipeline: exit_pipeline,
                           message: message)
    end
  end

  # Serve caches the given jobs and starts the gRPC server.
  # This function should be last called in the plugin main function.
  def self.Serve(jobs)
    # Cache the jobs for later processing.
    # We have to transform given jobs into suitable proto models.
    cached_jobs = []
    jobs.each do |job|
      # Transform manual interaction
      manual_interaction = nil
      if job.interaction != nil
        manual_interaction = Interface::ManualInteraction.new(description: job.interaction.desc,
                                                   type: job.interaction.type,
                                                   value: job.interaction.value)
      end

      # Transform arguments
      args = []
      if job.args != nil
        job.args.each do |arg|
          # Description and Value are optional.
          # Set default values for those.
          arg.desc = "" if arg.desc == nil
          arg.value = "" if arg.value == nil
            
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
              proto_job.dependson.push FNV.new.fnv1a_32(curr_job.title)
              dep_found = true
              break
            end
          end
          
          raise "job #{job.title} has dependency #{dep_job} which is not declared" unless dep_found == true
        end
      end

      # Create wrapper object
      wrapper_job = Interface::JobsWrapper.new(handler: job.handler, job: proto_job)
      cached_jobs.push wrapper_job
    end

    # Check if two jobs have the same title which is restricted.
    dup_map = {}
    cached_jobs.each do |job|
      dup_map[job.job.unique_id] = (dup_map[job.job.unique_id] || 0) + 1

      if dup_map[job.job.unique_id] > 1
        raise "duplicate job with the title #{job.title} found which is not allowed"
      end
    end

    # Get certificates path from env variables.
    cert_path = ENV["GAIA_PLUGIN_CERT"]
    key_path = ENV["GAIA_PLUGIN_KEY"]
    root_ca_path = ENV["GAIA_PLUGIN_CA_CERT"]

    # Check if variable is empty.
    raise "GAIA_PLUGIN_CERT not set" unless cert_path
    raise "GAIA_PLUGIN_KEY not set" unless key_path
    raise "GAIA_PLUGIN_CA_CERT not set" unless root_ca_path

    # Check if all certs are available.
    raise "cannot find path to certificate" unless File.file?(cert_path)
    raise "cannot find path to key" unless File.file?(key_path)
    raise "cannot find path to root CA certificate" unless File.file?(root_ca_path)

    # Implement health service.
    health_svc = Grpc::Health::Checker.new
    health_svc.add_status("plugin", Grpc::Health::V1::HealthCheckResponse::ServingStatus::SERVING)

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
    host = '127.0.0.1'
    s = GRPC::RpcServer.new
    port = s.add_http2_port(host+':0', credentials)
    s.handle(GRPCServer.new(cached_jobs))
    s.handle(health_svc)

    # Output the address and service name to stdout.
    # hashicorp go-plugin will use that to establish a connection.
    STDOUT.puts "1|2|tcp|#{host}:#{port}|grpc"

    s.run_till_terminated
  end
end
