# frozen_string_literal: true

class CommentsController < ActionController::Base
  include SiteAuthenticated

  skip_forgery_protection

  def create
    return not_found unless authenticate_site!

    release = current_site.current_release
    return not_found unless release

    comment = release.comments.create!(
      site: current_site,
      person: current_grant.person,
      grant: current_grant,
      body: params[:body],
      **verified_anchor(release)
    )

    render json: { id: comment.id }, status: :created
  rescue SiteSession::Rejected, Shortbread::Hosts::InvalidHost
    not_found
  rescue AnchorVerification::Rejected, ActiveRecord::RecordInvalid
    head :unprocessable_content
  end

  private

  # An Anchor is optional: a Site-level Comment carries no selection. When one is claimed it is
  # verified against the Release's stored bytes and re-derived from the server's own extraction.
  def verified_anchor(release)
    return {} if anchor_params.values.all?(&:blank?)

    verified = AnchorVerification.call(release:, payload: anchor_params)
    verified.to_h
  end

  def anchor_params
    @anchor_params ||= params.permit(:path, :quote, :start_offset).to_h.symbolize_keys
  end
end
