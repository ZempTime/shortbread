# frozen_string_literal: true

require "test_helper"

require "digest"

class InvitationPreviewTest < ActionDispatch::IntegrationTest
  test "known and unknown Invitations have the same side-effect-free preview" do
    invitation = issue_invitation
    before_state = invitation_state(invitation)

    get "/invitations/#{invitation.locator}", headers: { "Host" => "localhost" }
    known_preview = preview_snapshot

    assert_response :ok
    assert_equal before_state, invitation_state(invitation)
    assert_nil response.headers["Set-Cookie"]
    refute_includes response.body, invitation.locator

    unknown_locator = "z" * 32
    get "/invitations/#{unknown_locator}", headers: { "Host" => "localhost" }
    unknown_preview = preview_snapshot

    assert_response :ok
    assert_equal before_state, invitation_state(invitation)
    assert_nil response.headers["Set-Cookie"]
    refute_includes response.body, unknown_locator
    assert_equal known_preview, unknown_preview
  end

  test "HEAD returns the preview headers with an empty body and no side effects" do
    invitation = issue_invitation
    before_state = invitation_state(invitation)

    head "/invitations/#{invitation.locator}", headers: { "Host" => "localhost" }

    assert_response :ok
    assert_empty response.body
    assert_preview_headers
    assert_equal before_state, invitation_state(invitation)
    assert_nil response.headers["Set-Cookie"]
  end

  test "Site, wrong, and malformed hosts receive the same generic not found response" do
    path = "/invitations/#{"z" * 32}"
    snapshots = [ "first-site.sites.localhost", "wrong.example", "bad_host" ].map do |host|
      get path, headers: { "Host" => host }
      assert_response :not_found
      assert_empty response.body
      assert_nil response.headers["Set-Cookie"]
      response.body
    end

    assert_equal [ "", "", "" ], snapshots
  end

  test "the self-contained preview removes the fragment before wiring explicit acceptance" do
    get "/invitations/#{"z" * 32}", headers: { "Host" => "localhost" }

    assert_response :ok
    assert_preview_headers
    refute_match(/\s(?:src|href)\s*=/i, response.body)
    assert_equal 1, response.body.scan(/<script\b/i).size
    assert_includes response.body, 'data-shortbread-invitation-accept="true"'

    capture = response.body.index("const secret = /^#[A-Za-z0-9_-]{43}$/")
    removal = response.body.index("history.replaceState(null, \"\", window.location.pathname)")
    ready = response.body.index('document.addEventListener("DOMContentLoaded"')
    click = response.body.index('button.addEventListener("click"')
    action = response.body.index("form.action = `${window.location.pathname}/accept`")
    submit = response.body.index("form.submit()")

    assert [ capture, removal, ready, click, action, submit ].all?
    assert_operator capture, :<, removal
    assert_operator removal, :<, ready
    assert_operator ready, :<, click
    assert_operator click, :<, action
    assert_operator action, :<, submit
    assert_operator response.body.index("<script"), :<, response.body.index("</head>")
    assert_operator response.body.index("</head>"), :<, response.body.index("<button")
  end

  private

  def issue_invitation
    site = Site.create!(slug: "first-site", name: "First Site")
    person = Person.create!(first_name: "Avery")
    grant = Grant.create!(site:, person:)
    Invitation.issue!(grant:, secret_digest: Digest::SHA256.hexdigest("synthetic secret"))
  end

  def invitation_state(invitation)
    [ Invitation.count, SiteHandoff.count, invitation.reload.accepted_at, invitation.revoked_at,
      invitation.created_at, invitation.updated_at ]
  end

  def preview_snapshot
    assert_preview_headers
    nonce = response.headers.fetch("Content-Security-Policy").match(/'nonce-([^']+)'/)[1]

    {
      status: response.status,
      body: response.body.gsub(nonce, "[nonce]"),
      content_security_policy: response.headers.fetch("Content-Security-Policy").gsub(nonce, "[nonce]"),
      content_type: response.media_type
    }
  end

  def assert_preview_headers
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "origin", response.headers["Referrer-Policy"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    policy = response.headers.fetch("Content-Security-Policy")
    nonce = policy.match(/script-src 'nonce-([^']+)'/)&.[](1)
    assert nonce
    assert_includes response.body, %(nonce="#{nonce}") unless request.head?
    assert_includes policy, "default-src 'none'"
    assert_includes policy, "form-action 'self'"
    assert_includes policy, "frame-ancestors 'none'"
  end
end
