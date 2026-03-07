# frozen_string_literal: true

require "openssl"

module Jobcelis
  module WebhookVerifier
    # Verify a webhook signature using HMAC-SHA256.
    #
    # @param secret    [String] The webhook signing secret.
    # @param body      [String] The raw request body.
    # @param signature [String] The signature from the X-Signature header.
    # @return [Boolean] true if the signature is valid.
    def self.verify(secret:, body:, signature:)
      expected = OpenSSL::HMAC.hexdigest("SHA256", secret, body)
      return false if signature.nil? || signature.empty?

      OpenSSL.secure_compare(expected, signature)
    end
  end
end
