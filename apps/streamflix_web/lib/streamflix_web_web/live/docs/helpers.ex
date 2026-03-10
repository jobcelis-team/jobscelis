defmodule StreamflixWebWeb.Docs.Helpers do
  @moduledoc """
  Pure data functions for the documentation page.
  Contains SDK labels, install commands, usage examples,
  and framework webhook verification code samples.
  """

  # ── SDK labels ──────────────────────────────────────────────────────

  def sdk_label("nodejs"), do: "Node.js"
  def sdk_label("python"), do: "Python"
  def sdk_label("go"), do: "Go"
  def sdk_label("php"), do: "PHP"
  def sdk_label("ruby"), do: "Ruby"
  def sdk_label("elixir"), do: "Elixir"
  def sdk_label("dotnet"), do: ".NET"
  def sdk_label("rust"), do: "Rust"
  def sdk_label("swift"), do: "Swift"
  def sdk_label("java"), do: "Java"
  def sdk_label("dart"), do: "Dart"
  def sdk_label("kotlin"), do: "Kotlin"

  # ── SDK install commands ────────────────────────────────────────────

  def sdk_install("nodejs"), do: "npm install @jobcelis/sdk"
  def sdk_install("python"), do: "pip install jobcelis"
  def sdk_install("go"), do: "go get github.com/vladimirCeli/go-jobcelis"
  def sdk_install("php"), do: "composer require jobcelis/sdk"
  def sdk_install("ruby"), do: "gem install jobcelis"
  def sdk_install("elixir"), do: ~s|{:jobcelis, "~> 1.0"}  # add to mix.exs deps|
  def sdk_install("dotnet"), do: "dotnet add package Jobcelis"
  def sdk_install("rust"), do: ~s|cargo add jobcelis|

  def sdk_install("swift"),
    do:
      ~s|// Swift Package Manager\n.package(url: "https://github.com/vladimirCeli/jobcelis-swift", from: "1.0.0")|

  def sdk_install("java"),
    do:
      ~s|<!-- Maven -->\n<dependency>\n  <groupId>com.jobcelis</groupId>\n  <artifactId>jobcelis</artifactId>\n  <version>1.0.0</version>\n</dependency>|

  def sdk_install("dart"), do: ~s|dart pub add jobcelis|
  def sdk_install("kotlin"), do: ~s|implementation("com.jobcelis:jobcelis:1.0.0")|

  # ── SDK usage: send_event ───────────────────────────────────────────

  def sdk_usage("nodejs", "send_event") do
    ~s|const { JobcelisClient } = require('@jobcelis/sdk');

const client = new JobcelisClient({ apiKey: 'YOUR_API_KEY' });

await client.sendEvent({
  topic: 'order.created',
  payload: { order_id: '12345', amount: 99.99 },
});|
  end

  def sdk_usage("python", "send_event") do
    ~s|from jobcelis import JobcelisClient

client = JobcelisClient(api_key="YOUR_API_KEY")

client.send_event("order.created", {"order_id": "12345", "amount": 99.99})|
  end

  def sdk_usage("go", "send_event") do
    ~s|client := jobcelis.NewClient("YOUR_API_KEY")

resp, err := client.SendEvent(ctx, jobcelis.EventRequest{
    Topic:   "order.created",
    Payload: map[string]interface{}{"order_id": "12345", "amount": 99.99},
})|
  end

  def sdk_usage("php", "send_event") do
    ~s|use Jobcelis\\JobcelisClient;

$client = new JobcelisClient('YOUR_API_KEY');

$response = $client->sendEvent([
    'topic' => 'order.created',
    'payload' => ['order_id' => '12345', 'amount' => 99.99],
]);|
  end

  def sdk_usage("ruby", "send_event") do
    ~s|require 'jobcelis'

client = Jobcelis::Client.new(api_key: 'YOUR_API_KEY')

response = client.send_event(
  topic: 'order.created',
  payload: { order_id: '12345', amount: 99.99 }
)|
  end

  def sdk_usage("elixir", "send_event") do
    ~s|client = Jobcelis.client(api_key: "YOUR_API_KEY")

{:ok, event} = Jobcelis.send_event(client,
  topic: "order.created",
  payload: %{order_id: "12345", amount: 99.99}
)|
  end

  def sdk_usage("dotnet", "send_event") do
    ~s|using Jobcelis;

var client = new JobcelisClient("YOUR_API_KEY");

var response = await client.SendEventAsync(new {
    topic = "order.created",
    payload = new { order_id = "12345", amount = 99.99 }
});|
  end

  def sdk_usage("rust", "send_event") do
    ~s|use jobcelis::JobcelisClient;

let client = JobcelisClient::new("YOUR_API_KEY");

let response = client.send_event(
    "order.created",
    serde_json::json!({"order_id": "12345", "amount": 99.99})
).await?;|
  end

  def sdk_usage("swift", "send_event") do
    ~s|import Jobcelis

let client = JobcelisClient(apiKey: "YOUR_API_KEY")

let response = try await client.sendEvent(
    topic: "order.created",
    payload: ["order_id": "12345", "amount": 99.99]
)|
  end

  def sdk_usage("java", "send_event") do
    ~s|import com.jobcelis.JobcelisClient;

JobcelisClient client = new JobcelisClient("YOUR_API_KEY");

JsonObject response = client.sendEvent(
    "order.created",
    Map.of("order_id", "12345", "amount", 99.99)
);|
  end

  def sdk_usage("dart", "send_event") do
    ~s|import 'package:jobcelis/jobcelis.dart';

final client = JobcelisClient(apiKey: 'YOUR_API_KEY');

final response = await client.sendEvent(
  topic: 'order.created',
  payload: {'order_id': '12345', 'amount': 99.99},
);|
  end

  def sdk_usage("kotlin", "send_event") do
    ~s|import com.jobcelis.JobcelisClient

val client = JobcelisClient("YOUR_API_KEY")

val response = client.sendEvent(
    topic = "order.created",
    payload = mapOf("order_id" to "12345", "amount" to 99.99)
)|
  end

  # ── SDK usage: verify_webhook ───────────────────────────────────────

  def sdk_usage("nodejs", "verify_webhook") do
    ~s|const crypto = require('crypto');

function verifySignature(secret, body, signature) {
  if (!signature.startsWith('sha256=')) return false;
  const received = signature.slice(7);
  const expected = crypto
    .createHmac('sha256', secret)
    .update(body)
    .digest('base64')
    .replace(/=+$/, '');
  const a = Buffer.from(received, 'base64');
  const b = Buffer.from(expected, 'base64');
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}|
  end

  def sdk_usage("python", "verify_webhook") do
    ~s|import base64, hashlib, hmac

def verify_signature(secret, body, signature):
    if not signature.startswith('sha256='):
        return False
    received = signature[7:]
    expected = base64.b64encode(
        hmac.new(secret.encode(), body.encode(), hashlib.sha256).digest()
    ).rstrip(b'=').decode()
    return hmac.compare_digest(received, expected)|
  end

  def sdk_usage("go", "verify_webhook") do
    ~s|import (
    "crypto/hmac"
    "crypto/sha256"
    "encoding/base64"
    "strings"
)

func VerifySignature(secret, body, signature string) bool {
    if !strings.HasPrefix(signature, "sha256=") {
        return false
    }
    received := signature[7:]
    mac := hmac.New(sha256.New, []byte(secret))
    mac.Write([]byte(body))
    expected := base64.RawStdEncoding.EncodeToString(mac.Sum(nil))
    return hmac.Equal([]byte(received), []byte(expected))
}|
  end

  def sdk_usage("php", "verify_webhook") do
    ~s|<?php
function verifySignature(string $secret, string $body, string $signature): bool {
    if (!str_starts_with($signature, 'sha256=')) return false;
    $received = substr($signature, 7);
    $expected = rtrim(base64_encode(
        hash_hmac('sha256', $body, $secret, true)
    ), '=');
    return hash_equals($received, $expected);
}|
  end

  def sdk_usage("ruby", "verify_webhook") do
    "require 'openssl'\n" <>
      "require 'base64'\n\n" <>
      "def verify_signature(secret, body, signature)\n" <>
      "  return false unless signature.start_with?('sha256=')\n" <>
      "  received = signature[7..]\n" <>
      "  expected = Base64.strict_encode64(\n" <>
      "    OpenSSL::HMAC.digest('sha256', secret, body)\n" <>
      "  ).delete_suffix('=')\n" <>
      "  Rack::Utils.secure_compare(received, expected)\n" <>
      "end"
  end

  def sdk_usage("elixir", "verify_webhook") do
    "defmodule WebhookVerifier do\n" <>
      "  def verify_signature(secret, body, signature) do\n" <>
      "    case signature do\n" <>
      "      \"sha256=\" <> received ->\n" <>
      "        expected =\n" <>
      "          :crypto.mac(:hmac, :sha256, secret, body)\n" <>
      "          |> Base.encode64(padding: false)\n" <>
      "        Plug.Crypto.secure_compare(received, expected)\n" <>
      "      _ ->\n" <>
      "        false\n" <>
      "    end\n" <>
      "  end\n" <>
      "end"
  end

  def sdk_usage("dotnet", "verify_webhook") do
    ~s|using System.Security.Cryptography;
using System.Text;

public static bool VerifySignature(string secret, string body, string signature) {
    if (!signature.StartsWith("sha256=")) return false;
    var received = signature.Substring(7);
    using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(secret));
    var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(body));
    var expected = Convert.ToBase64String(hash).TrimEnd('=');
    return CryptographicOperations.FixedTimeEquals(
        Encoding.UTF8.GetBytes(received),
        Encoding.UTF8.GetBytes(expected));
}|
  end

  def sdk_usage("rust", "verify_webhook") do
    ~s|use hmac::{Hmac, Mac};
use sha2::Sha256;
use base64::engine::general_purpose::STANDARD_NO_PAD;
use base64::Engine;

fn verify_signature(secret: &str, body: &str, signature: &str) -> bool {
    let received = match signature.strip_prefix("sha256=") {
        Some(s) => s,
        None => return false,
    };
    let mut mac = Hmac::<Sha256>::new_from_slice(secret.as_bytes()).unwrap();
    mac.update(body.as_bytes());
    let expected = STANDARD_NO_PAD.encode(mac.finalize().into_bytes());
    received == expected
}|
  end

  def sdk_usage("swift", "verify_webhook") do
    ~s|import CryptoKit
import Foundation

func verifySignature(secret: String, body: String, signature: String) -> Bool {
    guard signature.hasPrefix("sha256=") else { return false }
    let received = String(signature.dropFirst(7))
    let key = SymmetricKey(data: Data(secret.utf8))
    let mac = HMAC<SHA256>.authenticationCode(
        for: Data(body.utf8), using: key
    )
    let expected = Data(mac).base64EncodedString()
        .replacingOccurrences(of: "=", with: "")
    return received == expected
}|
  end

  def sdk_usage("java", "verify_webhook") do
    ~s|import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.util.Base64;

public static boolean verifySignature(String secret, String body, String signature) {
    if (!signature.startsWith("sha256=")) return false;
    String received = signature.substring(7);
    Mac mac = Mac.getInstance("HmacSHA256");
    mac.init(new SecretKeySpec(secret.getBytes("UTF-8"), "HmacSHA256"));
    byte[] hash = mac.doFinal(body.getBytes("UTF-8"));
    String expected = Base64.getEncoder().withoutPadding().encodeToString(hash);
    return MessageDigest.isEqual(received.getBytes(), expected.getBytes());
}|
  end

  def sdk_usage("dart", "verify_webhook") do
    ~s|import 'dart:convert';
import 'package:crypto/crypto.dart';

bool verifySignature(String secret, String body, String signature) {
  if (!signature.startsWith('sha256=')) return false;
  final received = signature.substring(7);
  final hmac = Hmac(sha256, utf8.encode(secret));
  final digest = hmac.convert(utf8.encode(body));
  final expected = base64Encode(digest.bytes).replaceAll('=', '');
  return received == expected;
}|
  end

  def sdk_usage("kotlin", "verify_webhook") do
    ~s|import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import java.security.MessageDigest
import java.util.Base64

fun verifySignature(secret: String, body: String, signature: String): Boolean {
    if (!signature.startsWith("sha256=")) return false
    val received = signature.removePrefix("sha256=")
    val mac = Mac.getInstance("HmacSHA256")
    mac.init(SecretKeySpec(secret.toByteArray(), "HmacSHA256"))
    val hash = mac.doFinal(body.toByteArray())
    val expected = Base64.getEncoder().withoutPadding().encodeToString(hash)
    return MessageDigest.isEqual(received.toByteArray(), expected.toByteArray())
}|
  end

  def sdk_usage(_, "verify_webhook") do
    ~s|// See the SDK documentation for your language's
// webhook verification implementation.
// All SDKs provide a verifySignature() helper.|
  end

  def sdk_usage(_, _), do: "// See SDK documentation for usage"

  # ── Framework webhook verification code ─────────────────────────────

  def framework_code(:express) do
    ~s|const crypto = require('crypto');

app.post('/webhook', express.raw({ type: '*/*' }), (req, res) => {
  const signature = req.headers['x-signature'];
  const body = req.body.toString();
  if (!verifySignature(process.env.WEBHOOK_SECRET, body, signature)) {
    return res.status(401).send('Invalid signature');
  }
  const event = JSON.parse(body);
  // Process event...
  res.sendStatus(200);
});|
  end

  def framework_code(:fastapi) do
    ~s|from fastapi import FastAPI, Request, HTTPException

@app.post("/webhook")
async def webhook(request: Request):
    body = (await request.body()).decode()
    signature = request.headers.get("x-signature", "")
    if not verify_signature(WEBHOOK_SECRET, body, signature):
        raise HTTPException(status_code=401, detail="Invalid signature")
    event = await request.json()
    # Process event...
    return {"ok": True}|
  end

  def framework_code(:gin) do
    ~s|func webhookHandler(c *gin.Context) {
    body, _ := io.ReadAll(c.Request.Body)
    signature := c.GetHeader("X-Signature")
    if !jobcelis.VerifyWebhookSignature(secret, string(body), signature) {
        c.JSON(401, gin.H{"error": "invalid signature"})
        return
    }
    // Process event...
    c.JSON(200, gin.H{"ok": true})
}|
  end

  def framework_code(:phoenix) do
    "defmodule MyAppWeb.WebhookController do\n" <>
      "  use MyAppWeb, :controller\n\n" <>
      "  def handle(conn, _params) do\n" <>
      "    {:ok, body, conn} = Plug.Conn.read_body(conn)\n" <>
      "    sig = Plug.Conn.get_req_header(conn, \"x-signature\") |> List.first(\"\")\n" <>
      "    if Jobcelis.WebhookVerifier.verify(secret, body, sig) do\n" <>
      "      event = Jason.decode!(body)\n" <>
      "      # Process event...\n" <>
      "      json(conn, %{ok: true})\n" <>
      "    else\n" <>
      "      conn |> put_status(401) |> json(%{error: \"invalid signature\"})\n" <>
      "    end\n" <>
      "  end\n" <>
      "end"
  end

  def framework_code(:laravel) do
    ~s|Route::post('/webhook', function (Request $request) {
    $body = $request->getContent();
    $signature = $request->header('X-Signature', '');
    if (!WebhookVerifier::verify($secret, $body, $signature)) {
        return response()->json(['error' => 'invalid signature'], 401);
    }
    $event = json_decode($body, true);
    // Process event...
    return response()->json(['ok' => true]);
});|
  end

  def framework_code(:spring) do
    "@PostMapping(\"/webhook\")\n" <>
      "public ResponseEntity<Map<String, Object>> webhook(\n" <>
      "        @RequestBody String body,\n" <>
      "        @RequestHeader(\"X-Signature\") String signature) {\n" <>
      "    if (!WebhookVerifier.verify(secret, body, signature)) {\n" <>
      "        return ResponseEntity.status(401).body(Map.of(\"error\", \"invalid signature\"));\n" <>
      "    }\n" <>
      "    // Process event...\n" <>
      "    return ResponseEntity.ok(Map.of(\"ok\", true));\n" <>
      "}"
  end

  def framework_code(:aspnet) do
    "[HttpPost(\"webhook\")]\n" <>
      "public async Task<IActionResult> Webhook() {\n" <>
      "    using var reader = new StreamReader(Request.Body);\n" <>
      "    var body = await reader.ReadToEndAsync();\n" <>
      "    var signature = Request.Headers[\"X-Signature\"].FirstOrDefault() ?? \"\";\n" <>
      "    if (!WebhookVerifier.Verify(secret, body, signature))\n" <>
      "        return Unauthorized(new { error = \"invalid signature\" });\n" <>
      "    // Process event...\n" <>
      "    return Ok(new { ok = true });\n" <>
      "}"
  end

  def framework_code(:rails) do
    "class WebhooksController < ApplicationController\n" <>
      "  skip_before_action :verify_authenticity_token\n\n" <>
      "  def handle\n" <>
      "    body = request.raw_post\n" <>
      "    signature = request.headers[\"X-Signature\"] || \"\"\n" <>
      "    unless Jobcelis::WebhookVerifier.verify(\n" <>
      "      secret: ENV[\"WEBHOOK_SECRET\"], body: body, signature: signature\n" <>
      "    )\n" <>
      "      return render json: { error: \"invalid signature\" }, status: 401\n" <>
      "    end\n" <>
      "    event = JSON.parse(body)\n" <>
      "    # Process event...\n" <>
      "    render json: { ok: true }\n" <>
      "  end\n" <>
      "end"
  end
end
