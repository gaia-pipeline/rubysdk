#!/usr/bin/env ruby

require 'grpc'
require 'lib/plugin_services_pb'

# GRPCServer provides an implementation of the Plugin service.
class GRPCServer < Plugin::Service
  def initialize(cached_jobs)
    @cached_jobs = cached_jobs
  end

  def GetJobs(empty)
    @cached_jobs do |job|
      yield job.job
    end
  end

  def ExecuteJob(job)
    @cached_jobs do |cached_job|
      cjob = cached_job unless cached_job.unique_id == job.unique_id
    end
  end

