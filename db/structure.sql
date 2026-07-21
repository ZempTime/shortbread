SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: shortbread_enforce_monotonic_release_number(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.shortbread_enforce_monotonic_release_number() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  expected_number bigint;
BEGIN
  PERFORM 1 FROM sites WHERE id = NEW.site_id FOR UPDATE;
  SELECT COALESCE(MAX(number), 0) + 1
    INTO expected_number
    FROM releases
    WHERE site_id = NEW.site_id;

  IF NEW.number <> expected_number THEN
    RAISE EXCEPTION 'Release number must be the next monotonic number for its Site'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: shortbread_guard_manifest_entry_membership(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.shortbread_guard_manifest_entry_membership() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  parent_finalized_at timestamp(6);
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'Shortbread immutable Manifest Entry rows cannot be changed' USING ERRCODE = '55000';
  END IF;
  SELECT finalized_at INTO parent_finalized_at FROM releases WHERE id = NEW.release_id FOR UPDATE;
  IF parent_finalized_at IS NOT NULL THEN
    RAISE EXCEPTION 'Manifest Entries cannot be added to a finalized Release' USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: shortbread_guard_publish_plan_lifecycle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.shortbread_guard_publish_plan_lifecycle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.state <> 'open' OR NEW.release_id IS NOT NULL OR NEW.finalized_at IS NOT NULL THEN
      RAISE EXCEPTION 'Publish Plan rows must begin open and unbound' USING ERRCODE = '55000';
    END IF;
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Publish Plan idempotency rows cannot be deleted' USING ERRCODE = '55000';
  END IF;
  IF OLD.state = 'open'
    AND NEW.state = 'open'
    AND OLD.release_id IS NULL
    AND NEW.release_id IS NOT NULL
    AND OLD.finalized_at IS NULL
    AND NEW.finalized_at IS NULL
    AND OLD.site_id IS NOT DISTINCT FROM NEW.site_id
    AND OLD.base_release_id IS NOT DISTINCT FROM NEW.base_release_id
    AND OLD.idempotency_key_digest IS NOT DISTINCT FROM NEW.idempotency_key_digest
    AND OLD.manifest_sha256 IS NOT DISTINCT FROM NEW.manifest_sha256
    AND OLD.manifest IS NOT DISTINCT FROM NEW.manifest
    AND OLD.expires_at IS NOT DISTINCT FROM NEW.expires_at
    AND EXISTS (
      SELECT 1 FROM releases
      WHERE id = NEW.release_id
        AND site_id = NEW.site_id
        AND finalized_at IS NULL
        AND manifest_sha256 = NEW.manifest_sha256
    ) THEN
    RETURN NEW;
  END IF;
  IF OLD.state = 'open'
    AND NEW.state = 'finalized'
    AND OLD.release_id IS NOT NULL
    AND NEW.release_id = OLD.release_id
    AND OLD.finalized_at IS NULL
    AND NEW.finalized_at IS NOT NULL
    AND OLD.site_id IS NOT DISTINCT FROM NEW.site_id
    AND OLD.base_release_id IS NOT DISTINCT FROM NEW.base_release_id
    AND OLD.idempotency_key_digest IS NOT DISTINCT FROM NEW.idempotency_key_digest
    AND OLD.manifest_sha256 IS NOT DISTINCT FROM NEW.manifest_sha256
    AND OLD.manifest IS NOT DISTINCT FROM NEW.manifest
    AND OLD.expires_at IS NOT DISTINCT FROM NEW.expires_at
    AND EXISTS (
      SELECT 1 FROM releases
      WHERE id = NEW.release_id
        AND site_id = NEW.site_id
        AND finalized_at IS NOT NULL
        AND manifest_sha256 = NEW.manifest_sha256
    ) THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'Publish Plan rows permit only exact finalization' USING ERRCODE = '55000';
END;
$$;


--
-- Name: shortbread_guard_release_lifecycle(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.shortbread_guard_release_lifecycle() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.finalized_at IS NOT NULL THEN
      RAISE EXCEPTION 'Release rows must be assembled before finalization' USING ERRCODE = '55000';
    END IF;
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Shortbread immutable Release rows cannot be deleted' USING ERRCODE = '55000';
  END IF;
  IF OLD.finalized_at IS NULL
    AND NEW.finalized_at IS NOT NULL
    AND OLD.site_id IS NOT DISTINCT FROM NEW.site_id
    AND OLD.number IS NOT DISTINCT FROM NEW.number
    AND OLD.manifest_sha256 IS NOT DISTINCT FROM NEW.manifest_sha256
    AND EXISTS (
      SELECT 1
      FROM publish_plans plan
      WHERE plan.release_id = OLD.id
        AND plan.state = 'open'
        AND plan.site_id = OLD.site_id
        AND plan.manifest_sha256 = OLD.manifest_sha256
        AND jsonb_typeof(plan.manifest->'entries') = 'array'
        AND jsonb_array_length(plan.manifest->'entries') = (
          SELECT COUNT(*) FROM manifest_entries WHERE release_id = OLD.id
        )
        AND jsonb_array_length(plan.manifest->'entries') = (
          SELECT COUNT(DISTINCT expected->>'path')
          FROM jsonb_array_elements(plan.manifest->'entries') expected
        )
        AND EXISTS (
          SELECT 1
          FROM jsonb_array_elements(plan.manifest->'entries') expected
          WHERE expected->>'path' = 'index.html'
            AND expected->>'content_type' = 'text/html'
            AND expected->>'offline_policy' = 'required'
        )
        AND NOT EXISTS (
          SELECT 1
          FROM jsonb_array_elements(plan.manifest->'entries') expected
          LEFT JOIN manifest_entries entry
            ON entry.release_id = OLD.id AND entry.path = expected->>'path'
          LEFT JOIN blobs blob ON blob.id = entry.blob_id
          WHERE expected->>'path' IS NULL
            OR entry.id IS NULL
            OR blob.sha256 IS DISTINCT FROM expected->>'sha256'
            OR entry.byte_size IS DISTINCT FROM (expected->>'size')::bigint
            OR entry.content_type IS DISTINCT FROM expected->>'content_type'
            OR entry.offline_policy IS DISTINCT FROM expected->>'offline_policy'
        )
    ) THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'Shortbread immutable Release rows cannot be updated' USING ERRCODE = '55000';
END;
$$;


--
-- Name: shortbread_reject_immutable_row_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.shortbread_reject_immutable_row_change() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'Shortbread immutable % rows cannot be changed', TG_TABLE_NAME USING ERRCODE = '55000';
END;
$$;


--
-- Name: shortbread_require_finalized_current_release(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.shortbread_require_finalized_current_release() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.current_release_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM releases release
    JOIN publish_plans plan ON plan.release_id = release.id
    WHERE release.id = NEW.current_release_id
      AND release.site_id = NEW.id
      AND release.finalized_at IS NOT NULL
      AND plan.site_id = NEW.id
      AND plan.state = 'finalized'
      AND plan.finalized_at IS NOT NULL
      AND plan.manifest_sha256 = release.manifest_sha256
  ) THEN
    RAISE EXCEPTION 'A Site current pointer must select its finalized Release' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blobs (
    id bigint NOT NULL,
    sha256 character varying(64) NOT NULL,
    byte_size bigint NOT NULL,
    storage_key character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT blobs_byte_size_nonnegative CHECK ((byte_size >= 0)),
    CONSTRAINT blobs_sha256_format CHECK (((sha256)::text ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blobs_id_seq OWNED BY public.blobs.id;


--
-- Name: grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grants (
    id bigint NOT NULL,
    site_id bigint NOT NULL,
    person_id bigint NOT NULL,
    offline_allowed boolean DEFAULT false NOT NULL,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.grants_id_seq OWNED BY public.grants.id;


--
-- Name: invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invitations (
    id bigint NOT NULL,
    grant_id bigint NOT NULL,
    locator character varying NOT NULL,
    secret_digest character varying(64) NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    accepted_at timestamp(6) without time zone,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT invitations_secret_digest_format CHECK (((secret_digest)::text ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: invitations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invitations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invitations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invitations_id_seq OWNED BY public.invitations.id;


--
-- Name: manifest_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.manifest_entries (
    id bigint NOT NULL,
    release_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    path character varying NOT NULL,
    byte_size bigint NOT NULL,
    content_type character varying NOT NULL,
    offline_policy character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT manifest_entries_byte_size_nonnegative CHECK ((byte_size >= 0)),
    CONSTRAINT manifest_entries_offline_policy CHECK (((offline_policy)::text = ANY ((ARRAY['required'::character varying, 'optional'::character varying, 'download'::character varying])::text[])))
);


--
-- Name: manifest_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.manifest_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: manifest_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.manifest_entries_id_seq OWNED BY public.manifest_entries.id;


--
-- Name: owner_ceremonies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.owner_ceremonies (
    id bigint NOT NULL,
    purpose character varying NOT NULL,
    authority character varying NOT NULL,
    secret_digest character varying(64) NOT NULL,
    challenge character varying(512),
    origin character varying(512),
    rp_id character varying(253),
    expires_at timestamp(6) without time zone NOT NULL,
    consumed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT owner_ceremonies_authority CHECK (((authority)::text = 'deployment'::text)),
    CONSTRAINT owner_ceremonies_authority_shape CHECK ((((purpose)::text = 'bootstrap'::text) AND ((authority)::text = 'deployment'::text))),
    CONSTRAINT owner_ceremonies_challenge_length CHECK (((challenge IS NULL) OR ((octet_length((challenge)::text) >= 16) AND (octet_length((challenge)::text) <= 512)))),
    CONSTRAINT owner_ceremonies_purpose CHECK (((purpose)::text = 'bootstrap'::text)),
    CONSTRAINT owner_ceremonies_secret_digest_format CHECK (((secret_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT owner_ceremonies_webauthn_shape CHECK ((((challenge IS NULL) AND (origin IS NULL) AND (rp_id IS NULL)) OR ((challenge IS NOT NULL) AND (origin IS NOT NULL) AND (rp_id IS NOT NULL))))
);


--
-- Name: owner_ceremonies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.owner_ceremonies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: owner_ceremonies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.owner_ceremonies_id_seq OWNED BY public.owner_ceremonies.id;


--
-- Name: owner_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.owner_credentials (
    id bigint NOT NULL,
    owner_id bigint NOT NULL,
    credential_id text NOT NULL,
    public_key text NOT NULL,
    sign_count bigint DEFAULT 0 NOT NULL,
    label character varying NOT NULL,
    transports jsonb DEFAULT '[]'::jsonb NOT NULL,
    last_used_at timestamp(6) without time zone,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT owner_credentials_label_length CHECK (((octet_length((label)::text) >= 1) AND (octet_length((label)::text) <= 100))),
    CONSTRAINT owner_credentials_material_length CHECK ((((octet_length(credential_id) >= 1) AND (octet_length(credential_id) <= 1366)) AND ((octet_length(public_key) >= 1) AND (octet_length(public_key) <= 16384)))),
    CONSTRAINT owner_credentials_sign_count_nonnegative CHECK ((sign_count >= 0)),
    CONSTRAINT owner_credentials_transports_array CHECK (((jsonb_typeof(transports) = 'array'::text) AND (transports <@ '["ble", "hybrid", "internal", "nfc", "smart-card", "usb"]'::jsonb) AND (jsonb_array_length(transports) <= 6)))
);


--
-- Name: owner_credentials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.owner_credentials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: owner_credentials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.owner_credentials_id_seq OWNED BY public.owner_credentials.id;


--
-- Name: owners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.owners (
    id bigint NOT NULL,
    singleton_key boolean DEFAULT true NOT NULL,
    webauthn_id character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT owners_singleton_key_true CHECK ((singleton_key = true)),
    CONSTRAINT owners_webauthn_id_length CHECK (((octet_length((webauthn_id)::text) >= 16) AND (octet_length((webauthn_id)::text) <= 255)))
);


--
-- Name: owners_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.owners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: owners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.owners_id_seq OWNED BY public.owners.id;


--
-- Name: people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.people (
    id bigint NOT NULL,
    first_name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: people_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.people_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: people_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.people_id_seq OWNED BY public.people.id;


--
-- Name: publish_plans; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.publish_plans (
    id bigint NOT NULL,
    site_id bigint NOT NULL,
    base_release_id bigint,
    release_id bigint,
    idempotency_key_digest character varying(64) NOT NULL,
    manifest_sha256 character varying(64) NOT NULL,
    manifest jsonb NOT NULL,
    state character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    finalized_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT publish_plans_idempotency_key_digest_format CHECK (((idempotency_key_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT publish_plans_manifest_sha256_format CHECK (((manifest_sha256)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT publish_plans_state CHECK (((state)::text = ANY ((ARRAY['open'::character varying, 'finalized'::character varying])::text[])))
);


--
-- Name: publish_plans_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.publish_plans_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: publish_plans_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.publish_plans_id_seq OWNED BY public.publish_plans.id;


--
-- Name: release_rollbacks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.release_rollbacks (
    id bigint NOT NULL,
    site_id bigint NOT NULL,
    from_release_id bigint NOT NULL,
    to_release_id bigint NOT NULL,
    idempotency_key_digest character varying(64) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT release_rollbacks_idempotency_key_digest_format CHECK (((idempotency_key_digest)::text ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: release_rollbacks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.release_rollbacks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: release_rollbacks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.release_rollbacks_id_seq OWNED BY public.release_rollbacks.id;


--
-- Name: releases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.releases (
    id bigint NOT NULL,
    site_id bigint NOT NULL,
    number bigint NOT NULL,
    manifest_sha256 character varying(64) NOT NULL,
    finalized_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT releases_manifest_sha256_format CHECK (((manifest_sha256)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT releases_number_positive CHECK ((number > 0))
);


--
-- Name: releases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.releases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: releases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.releases_id_seq OWNED BY public.releases.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: site_handoffs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.site_handoffs (
    id bigint NOT NULL,
    grant_id bigint NOT NULL,
    invitation_id bigint NOT NULL,
    audience character varying NOT NULL,
    nonce_digest character varying(64) NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    consumed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT site_handoffs_nonce_digest_format CHECK (((nonce_digest)::text ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: site_handoffs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.site_handoffs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: site_handoffs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.site_handoffs_id_seq OWNED BY public.site_handoffs.id;


--
-- Name: sites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sites (
    id bigint NOT NULL,
    slug character varying NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    current_release_id bigint
);


--
-- Name: sites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sites_id_seq OWNED BY public.sites.id;


--
-- Name: blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blobs ALTER COLUMN id SET DEFAULT nextval('public.blobs_id_seq'::regclass);


--
-- Name: grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grants ALTER COLUMN id SET DEFAULT nextval('public.grants_id_seq'::regclass);


--
-- Name: invitations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations ALTER COLUMN id SET DEFAULT nextval('public.invitations_id_seq'::regclass);


--
-- Name: manifest_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifest_entries ALTER COLUMN id SET DEFAULT nextval('public.manifest_entries_id_seq'::regclass);


--
-- Name: owner_ceremonies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.owner_ceremonies ALTER COLUMN id SET DEFAULT nextval('public.owner_ceremonies_id_seq'::regclass);


--
-- Name: owner_credentials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.owner_credentials ALTER COLUMN id SET DEFAULT nextval('public.owner_credentials_id_seq'::regclass);


--
-- Name: owners id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.owners ALTER COLUMN id SET DEFAULT nextval('public.owners_id_seq'::regclass);


--
-- Name: people id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people ALTER COLUMN id SET DEFAULT nextval('public.people_id_seq'::regclass);


--
-- Name: publish_plans id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publish_plans ALTER COLUMN id SET DEFAULT nextval('public.publish_plans_id_seq'::regclass);


--
-- Name: release_rollbacks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.release_rollbacks ALTER COLUMN id SET DEFAULT nextval('public.release_rollbacks_id_seq'::regclass);


--
-- Name: releases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.releases ALTER COLUMN id SET DEFAULT nextval('public.releases_id_seq'::regclass);


--
-- Name: site_handoffs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_handoffs ALTER COLUMN id SET DEFAULT nextval('public.site_handoffs_id_seq'::regclass);


--
-- Name: sites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites ALTER COLUMN id SET DEFAULT nextval('public.sites_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: blobs blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blobs
    ADD CONSTRAINT blobs_pkey PRIMARY KEY (id);


--
-- Name: grants grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grants
    ADD CONSTRAINT grants_pkey PRIMARY KEY (id);


--
-- Name: invitations invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT invitations_pkey PRIMARY KEY (id);


--
-- Name: manifest_entries manifest_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifest_entries
    ADD CONSTRAINT manifest_entries_pkey PRIMARY KEY (id);


--
-- Name: owner_ceremonies owner_ceremonies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.owner_ceremonies
    ADD CONSTRAINT owner_ceremonies_pkey PRIMARY KEY (id);


--
-- Name: owner_credentials owner_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.owner_credentials
    ADD CONSTRAINT owner_credentials_pkey PRIMARY KEY (id);


--
-- Name: owners owners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.owners
    ADD CONSTRAINT owners_pkey PRIMARY KEY (id);


--
-- Name: people people_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.people
    ADD CONSTRAINT people_pkey PRIMARY KEY (id);


--
-- Name: publish_plans publish_plans_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publish_plans
    ADD CONSTRAINT publish_plans_pkey PRIMARY KEY (id);


--
-- Name: release_rollbacks release_rollbacks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.release_rollbacks
    ADD CONSTRAINT release_rollbacks_pkey PRIMARY KEY (id);


--
-- Name: releases releases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.releases
    ADD CONSTRAINT releases_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: site_handoffs site_handoffs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_handoffs
    ADD CONSTRAINT site_handoffs_pkey PRIMARY KEY (id);


--
-- Name: sites sites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites
    ADD CONSTRAINT sites_pkey PRIMARY KEY (id);


--
-- Name: index_blobs_on_sha256; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_blobs_on_sha256 ON public.blobs USING btree (sha256);


--
-- Name: index_blobs_on_storage_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_blobs_on_storage_key ON public.blobs USING btree (storage_key);


--
-- Name: index_grants_on_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_grants_on_person_id ON public.grants USING btree (person_id);


--
-- Name: index_grants_on_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_grants_on_site_id ON public.grants USING btree (site_id);


--
-- Name: index_grants_on_site_id_and_person_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_grants_on_site_id_and_person_id ON public.grants USING btree (site_id, person_id);


--
-- Name: index_invitations_on_grant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invitations_on_grant_id ON public.invitations USING btree (grant_id);


--
-- Name: index_invitations_on_locator; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invitations_on_locator ON public.invitations USING btree (locator);


--
-- Name: index_invitations_on_secret_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_invitations_on_secret_digest ON public.invitations USING btree (secret_digest);


--
-- Name: index_manifest_entries_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_manifest_entries_on_blob_id ON public.manifest_entries USING btree (blob_id);


--
-- Name: index_manifest_entries_on_release_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_manifest_entries_on_release_id ON public.manifest_entries USING btree (release_id);


--
-- Name: index_manifest_entries_on_release_id_and_path; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_manifest_entries_on_release_id_and_path ON public.manifest_entries USING btree (release_id, path);


--
-- Name: index_owner_ceremonies_on_secret_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_owner_ceremonies_on_secret_digest ON public.owner_ceremonies USING btree (secret_digest);


--
-- Name: index_owner_credentials_on_credential_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_owner_credentials_on_credential_id ON public.owner_credentials USING btree (credential_id);


--
-- Name: index_owner_credentials_on_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_owner_credentials_on_owner_id ON public.owner_credentials USING btree (owner_id);


--
-- Name: index_owners_on_singleton_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_owners_on_singleton_key ON public.owners USING btree (singleton_key);


--
-- Name: index_owners_on_webauthn_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_owners_on_webauthn_id ON public.owners USING btree (webauthn_id);


--
-- Name: index_publish_plans_on_base_release_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publish_plans_on_base_release_id ON public.publish_plans USING btree (base_release_id);


--
-- Name: index_publish_plans_on_release_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publish_plans_on_release_id ON public.publish_plans USING btree (release_id);


--
-- Name: index_publish_plans_on_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_publish_plans_on_site_id ON public.publish_plans USING btree (site_id);


--
-- Name: index_publish_plans_on_site_id_and_idempotency_key_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_publish_plans_on_site_id_and_idempotency_key_digest ON public.publish_plans USING btree (site_id, idempotency_key_digest);


--
-- Name: index_release_rollbacks_on_from_release_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_release_rollbacks_on_from_release_id ON public.release_rollbacks USING btree (from_release_id);


--
-- Name: index_release_rollbacks_on_site_and_key_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_release_rollbacks_on_site_and_key_digest ON public.release_rollbacks USING btree (site_id, idempotency_key_digest);


--
-- Name: index_release_rollbacks_on_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_release_rollbacks_on_site_id ON public.release_rollbacks USING btree (site_id);


--
-- Name: index_release_rollbacks_on_to_release_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_release_rollbacks_on_to_release_id ON public.release_rollbacks USING btree (to_release_id);


--
-- Name: index_releases_on_id_and_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_releases_on_id_and_site_id ON public.releases USING btree (id, site_id);


--
-- Name: index_releases_on_site_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_releases_on_site_id ON public.releases USING btree (site_id);


--
-- Name: index_releases_on_site_id_and_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_releases_on_site_id_and_number ON public.releases USING btree (site_id, number);


--
-- Name: index_site_handoffs_on_grant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_site_handoffs_on_grant_id ON public.site_handoffs USING btree (grant_id);


--
-- Name: index_site_handoffs_on_invitation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_site_handoffs_on_invitation_id ON public.site_handoffs USING btree (invitation_id);


--
-- Name: index_site_handoffs_on_nonce_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_site_handoffs_on_nonce_digest ON public.site_handoffs USING btree (nonce_digest);


--
-- Name: index_sites_on_current_release_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sites_on_current_release_id ON public.sites USING btree (current_release_id);


--
-- Name: index_sites_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sites_on_slug ON public.sites USING btree (slug);


--
-- Name: sites shortbread_finalized_current_release; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER shortbread_finalized_current_release BEFORE INSERT OR UPDATE OF current_release_id ON public.sites FOR EACH ROW EXECUTE FUNCTION public.shortbread_require_finalized_current_release();


--
-- Name: release_rollbacks shortbread_immutable_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER shortbread_immutable_change BEFORE DELETE OR UPDATE ON public.release_rollbacks FOR EACH ROW EXECUTE FUNCTION public.shortbread_reject_immutable_row_change();


--
-- Name: manifest_entries shortbread_manifest_entry_membership; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER shortbread_manifest_entry_membership BEFORE INSERT OR DELETE OR UPDATE ON public.manifest_entries FOR EACH ROW EXECUTE FUNCTION public.shortbread_guard_manifest_entry_membership();


--
-- Name: releases shortbread_monotonic_release_number; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER shortbread_monotonic_release_number BEFORE INSERT ON public.releases FOR EACH ROW EXECUTE FUNCTION public.shortbread_enforce_monotonic_release_number();


--
-- Name: publish_plans shortbread_publish_plan_lifecycle; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER shortbread_publish_plan_lifecycle BEFORE INSERT OR DELETE OR UPDATE ON public.publish_plans FOR EACH ROW EXECUTE FUNCTION public.shortbread_guard_publish_plan_lifecycle();


--
-- Name: releases shortbread_release_lifecycle; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER shortbread_release_lifecycle BEFORE INSERT OR DELETE OR UPDATE ON public.releases FOR EACH ROW EXECUTE FUNCTION public.shortbread_guard_release_lifecycle();


--
-- Name: publish_plans fk_publish_plans_base_release_same_site; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publish_plans
    ADD CONSTRAINT fk_publish_plans_base_release_same_site FOREIGN KEY (base_release_id, site_id) REFERENCES public.releases(id, site_id);


--
-- Name: publish_plans fk_publish_plans_release_same_site; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publish_plans
    ADD CONSTRAINT fk_publish_plans_release_same_site FOREIGN KEY (release_id, site_id) REFERENCES public.releases(id, site_id);


--
-- Name: releases fk_rails_00f1523b8e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.releases
    ADD CONSTRAINT fk_rails_00f1523b8e FOREIGN KEY (site_id) REFERENCES public.sites(id);


--
-- Name: release_rollbacks fk_rails_0e8c6914b0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.release_rollbacks
    ADD CONSTRAINT fk_rails_0e8c6914b0 FOREIGN KEY (site_id) REFERENCES public.sites(id);


--
-- Name: manifest_entries fk_rails_1d5aa615b7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifest_entries
    ADD CONSTRAINT fk_rails_1d5aa615b7 FOREIGN KEY (release_id) REFERENCES public.releases(id);


--
-- Name: site_handoffs fk_rails_1d7d0d1ed6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_handoffs
    ADD CONSTRAINT fk_rails_1d7d0d1ed6 FOREIGN KEY (invitation_id) REFERENCES public.invitations(id);


--
-- Name: publish_plans fk_rails_33595e40f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publish_plans
    ADD CONSTRAINT fk_rails_33595e40f9 FOREIGN KEY (site_id) REFERENCES public.sites(id);


--
-- Name: grants fk_rails_54cb50c22d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grants
    ADD CONSTRAINT fk_rails_54cb50c22d FOREIGN KEY (site_id) REFERENCES public.sites(id);


--
-- Name: invitations fk_rails_7df307c776; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invitations
    ADD CONSTRAINT fk_rails_7df307c776 FOREIGN KEY (grant_id) REFERENCES public.grants(id);


--
-- Name: site_handoffs fk_rails_7fd66b58cf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.site_handoffs
    ADD CONSTRAINT fk_rails_7fd66b58cf FOREIGN KEY (grant_id) REFERENCES public.grants(id);


--
-- Name: owner_credentials fk_rails_9bfe92cf76; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.owner_credentials
    ADD CONSTRAINT fk_rails_9bfe92cf76 FOREIGN KEY (owner_id) REFERENCES public.owners(id);


--
-- Name: publish_plans fk_rails_9f72463588; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publish_plans
    ADD CONSTRAINT fk_rails_9f72463588 FOREIGN KEY (release_id) REFERENCES public.releases(id);


--
-- Name: grants fk_rails_db257b513b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grants
    ADD CONSTRAINT fk_rails_db257b513b FOREIGN KEY (person_id) REFERENCES public.people(id);


--
-- Name: publish_plans fk_rails_e422d69063; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.publish_plans
    ADD CONSTRAINT fk_rails_e422d69063 FOREIGN KEY (base_release_id) REFERENCES public.releases(id);


--
-- Name: sites fk_rails_f784357003; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites
    ADD CONSTRAINT fk_rails_f784357003 FOREIGN KEY (current_release_id) REFERENCES public.releases(id);


--
-- Name: manifest_entries fk_rails_ffdc6d4884; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.manifest_entries
    ADD CONSTRAINT fk_rails_ffdc6d4884 FOREIGN KEY (blob_id) REFERENCES public.blobs(id);


--
-- Name: release_rollbacks fk_release_rollbacks_from_same_site; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.release_rollbacks
    ADD CONSTRAINT fk_release_rollbacks_from_same_site FOREIGN KEY (from_release_id, site_id) REFERENCES public.releases(id, site_id);


--
-- Name: release_rollbacks fk_release_rollbacks_to_same_site; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.release_rollbacks
    ADD CONSTRAINT fk_release_rollbacks_to_same_site FOREIGN KEY (to_release_id, site_id) REFERENCES public.releases(id, site_id);


--
-- Name: sites fk_sites_current_release_same_site; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sites
    ADD CONSTRAINT fk_sites_current_release_same_site FOREIGN KEY (current_release_id, id) REFERENCES public.releases(id, site_id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260720122000'),
('20260720121000'),
('20260720120000'),
('20260719145000'),
('20260719144000'),
('20260719143000'),
('20260719142000'),
('20260719141000'),
('20260719140000');
