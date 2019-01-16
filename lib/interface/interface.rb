#!/usr/bin/env ruby

module Interface
  # Constants
  TextFieldInput = "textfield"
  TextAreaInput  = "textarea"
  BoolInput      = "boolean"
  VaultInput     = "vault"

  class Job
    attr_accessor :handler, :title, :desc, :dependson, :args, :interaction
    
    def initialize(params)
      params.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end
  end

  class Argument
    attr_accessor :desc, :type, :key, :value
    
    def initialize(params)
      params.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end
  end

  class ManualInteraction
    attr_accessor :desc, :type, :value
    
    def initialize(params)
      params.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end
  end

  class JobsWrapper 
    attr_accessor :handler, :job
    
    def initialize(params)
      params.each do |key, value|
        instance_variable_set("@#{key}", value)
      end
    end
  end

  class ErrorExitPipeline < StandardError
  end
end

