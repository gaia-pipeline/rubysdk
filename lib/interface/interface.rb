#!/usr/bin/env ruby

module Interface
  class Job
    attr_accessor :handler, :title, :desc, :dependson, :args, :interaction
    
    def initialize(handler=nil, title="", desc="", dependson=[], args=[], interaction=nil)
      @handler = handler
      @title = title
      @desc = desc
      @dependson = dependson
      @args = args
      @interaction = interaction
    end
  end

  class Argument
    attr_accessor :desc, :type, :key, :value
    
    def initialize(desc="", type=nil, key="", value="")
      @desc = desc
      @type = type
      @key = key
      @value = value
    end
  end

  class ManualInteraction
    attr_accessor :desc, :type, :value
    
    def initialize(desc="", type=nil, value="")
      @desc = desc
      @type = type
      @value = value
    end
  end

  class JobsWrapper 
    attr_accessor :handler, :job
    
    def initialize(handler=nil, job=nil)
      @handler = handler
      @job = job
    end
  end

  class ErrorExitPipeline < StandardError
  end
end

