# frozen_string_literal: true

require "test_helper"

class StableIdentityTest < ActiveSupport::TestCase
  test "a persisted Site keeps its slug while its name remains mutable" do
    site = Site.create!(slug: "first-site", name: "First Site")

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      site.update!(slug: "renamed-site")
    end
    assert_equal "first-site", site.reload.slug

    site.update!(name: "Renamed Site")

    assert_equal "Renamed Site", site.reload.name
  end

  test "a persisted Grant keeps its Site and Person while its policy state remains mutable" do
    site = Site.create!(slug: "first-site", name: "First Site")
    other_site = Site.create!(slug: "other-site", name: "Other Site")
    person = Person.create!(first_name: "Avery")
    other_person = Person.create!(first_name: "Blair")
    grant = Grant.create!(site:, person:)

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      grant.update!(site_id: other_site.id)
    end
    assert_equal site, grant.reload.site

    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      grant.update!(person_id: other_person.id)
    end
    assert_equal person, grant.reload.person

    revoked_at = Time.current
    grant.update!(offline_allowed: true, revoked_at:)

    grant.reload
    assert_predicate grant, :offline_allowed?
    assert_equal revoked_at, grant.revoked_at
  end

  test "a Site slug must fit the configured complete Site hostname" do
    longest_apex = [ "a" * 63, "b" * 63, "c" * 63, "d" * 53 ].join(".")

    with_apex_host(longest_apex) do
      site = Site.create!(slug: "s", name: "One-Character Site")
      site.update!(name: "Renamed Site")
      assert_equal "Renamed Site", site.reload.name

      oversized = Site.new(slug: "ss", name: "Oversized Site")
      assert_not oversized.save
      assert oversized.errors.of_kind?(:slug, :invalid)
    end
  end

  private

  def with_apex_host(value)
    previous = ENV["SHORTBREAD_APEX_HOST"]
    ENV["SHORTBREAD_APEX_HOST"] = value
    yield
  ensure
    previous.nil? ? ENV.delete("SHORTBREAD_APEX_HOST") : ENV["SHORTBREAD_APEX_HOST"] = previous
  end
end
