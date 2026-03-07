# frozen_string_literal: true

module Jobcelis
  class Error < StandardError
    attr_reader :status, :detail

    def initialize(status, detail)
      @status = status
      @detail = detail
      super("HTTP #{status}: #{detail}")
    end
  end
end
