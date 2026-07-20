# frozen_string_literal: true

class SiteSession
  CIPHER = "aes-256-gcm"
  KEY_SALT = "shortbread/site-session/v1"
  PURPOSE = "shortbread-site-session-v1"
  LIFETIME = 30.days

  Issued = Data.define(:token, :expires_at)

  class Rejected < StandardError
    MESSAGE = "site session rejected"

    def initialize = super(MESSAGE)
  end

  class << self
    def issue(grant:, audience:, now:)
      new.issue(grant:, audience:, now:)
    end

    def authenticate(token:, audience:, site:, now:)
      new.authenticate(token:, audience:, site:, now:)
    end

    def cookie_name(secure:)
      secure ? "__Host-shortbread_site" : "shortbread_site"
    end

    def cookie_options(secure:, expires_at:)
      {
        secure: !!secure,
        httponly: true,
        path: "/",
        same_site: :lax,
        expires: expires_at
      }
    end
  end

  def issue(grant:, audience:, now:)
    reject! unless grant.is_a?(Grant) && grant.persisted? && valid_audience?(audience)

    persisted_grant = Grant.active.find_by(id: grant.id)
    reject! unless persisted_grant

    expires_at = now + LIFETIME
    token = encryptor.encrypt_and_sign(
      claims(grant: persisted_grant, audience:, expires_at:),
      purpose: PURPOSE
    )

    Issued.new(token:, expires_at:)
  end

  def authenticate(token:, audience:, site:, now:)
    reject! unless token.is_a?(String) && token.present?
    reject! unless valid_audience?(audience)
    reject! unless site.is_a?(Site) && site.persisted?

    claims = encryptor.decrypt_and_verify(token, purpose: PURPOSE)
    reject! unless valid_claims?(claims:, audience:, site:, now:)

    Grant.active.find_by(id: claims["grant_id"], site_id: site.id) || reject!
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    reject!
  end

  private

  def claims(grant:, audience:, expires_at:)
    {
      "grant_id" => grant.id,
      "site_id" => grant.site_id,
      "audience" => audience,
      "expires_at" => expires_at.to_f
    }
  end

  def encryptor
    key = Rails.application.key_generator.generate_key(
      KEY_SALT,
      ActiveSupport::MessageEncryptor.key_len(CIPHER)
    )
    ActiveSupport::MessageEncryptor.new(key, cipher: CIPHER, serializer: JSON)
  end

  def valid_audience?(audience)
    audience.is_a?(String) && audience.present?
  end

  def valid_claims?(claims:, audience:, site:, now:)
    claims.is_a?(Hash) &&
      claims["grant_id"].is_a?(Integer) &&
      claims["site_id"] == site.id &&
      claims["audience"] == audience &&
      claims["expires_at"].is_a?(Numeric) &&
      claims["expires_at"] > now.to_f
  end

  def reject!
    raise Rejected
  end
end
