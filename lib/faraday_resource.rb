require "faraday_resource/version"

module FaradayResource
  class << self
    attr_reader :config

    def configure
        @config = FaradayResourceConfig.instance
        yield(@config) if block_given?
    end
  end

  class FaradayResourceConfig
    attr_accessor :url, :content_type
    include Singleton
  end
end

require 'faraday_resource/base'
