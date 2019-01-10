#!/usr/bin/env ruby

class Job
  def initialize(handler=nil, title="", desc="", dependson=[], args=[], interaction=nil)
    @handler = handler
    @title = title
    @desc = desc
    @dependson = dependson
    @args = args
    @interaction = interaction
  end

  class << self
    attr_accessor :args
  end
end

class Argument
  def initialize(desc="", type=nil, key="", value="")
    @desc = desc
    @type = type
    @key = key
    @value = value
  end

  class << self
    attr_accessor :key
    attr_accessor :value
  end
end

class ManualInteraction
  def initialize(desc="", type=nil, value="")
    @desc = desc
    @type = type
    @value = value
  end
end

class JobsWrapper 
  def initialize(handler=nil, job=nil)
    @handler = handler
    @job = job
  end
end

class ErrorExitPipeline < StandardError
end


