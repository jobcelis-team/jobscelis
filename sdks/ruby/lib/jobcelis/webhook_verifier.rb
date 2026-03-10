# frozen_string_literal: true

require "openssl"
require "base64"

module Jobcelis
  module WebhookVerifier
    # Verify a webhook signature using HMAC-SHA256 (Base64, no padding).
    #
    # @param secret    [String] The webhook signing secret.
    # @param body      [String] The raw request body.
    # @param signature [String] The signature from the X-Signature header (format: "sha256=<base64>").
    # @return [Boolean] true if the signature is valid.
    def self.verify(secret:, body:, signature:)
      return false if signature.nil? || signature.empty?

      prefix = "sha256="
      return false unless signature.start_with?(prefix)

      received_sig = signature[prefix.length..]
      digest = OpenSSL::HMAC.digest("SHA256", secret, body)
      expected = Base64.strict_encode64(digest).delete("=")

      OpenSSL.secure_compare(expected, received_sig)
    end
  end
end
