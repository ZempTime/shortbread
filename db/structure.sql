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
-- Name: shortbread_reject_immutable_row_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.shortbread_reject_immutable_row_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'Shortbread immutable % rows cannot be updated', TG_TABLE_NAME
    USING ERRCODE = '55000';
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
    byte_size bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    sha256 character varying(64) NOT NULL,
    storage_key character varying NOT NULL,
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
    created_at timestamp(6) without time zone NOT NULL,
    offline_allowed boolean DEFAULT false NOT NULL,
    person_id bigint NOT NULL,
    revoked_at timestamp(6) without time zone,
    site_id bigint NOT NULL,
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
    accepted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    grant_id bigint NOT NULL,
    locator character varying NOT NULL,
    revoked_at timestamp(6) without time zone,
    secret_digest character varying(64) NOT NULL,
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
    blob_id bigint NOT NULL,
    byte_size bigint NOT NULL,
    content_type character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    offline_policy character varying NOT NULL,
    path character varying NOT NULL,
    release_id bigint NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT manifest_entries_byte_size_nonnegative CHECK ((byte_size >= 0)),
    CONSTRAINT manifest_entries_offline_policy CHECK (((offline_policy)::text = ANY (ARRAY[('required'::character varying)::text, ('optional'::character varying)::text, ('download'::character varying)::text])))
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
-- Name: people; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.people (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    first_name character varying NOT NULL,
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
    base_release_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    finalized_at timestamp(6) without time zone,
    idempotency_key_digest character varying(64) NOT NULL,
    manifest jsonb NOT NULL,
    manifest_sha256 character varying(64) NOT NULL,
    release_id bigint,
    site_id bigint NOT NULL,
    state character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT publish_plans_idempotency_key_digest_format CHECK (((idempotency_key_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT publish_plans_manifest_sha256_format CHECK (((manifest_sha256)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT publish_plans_state CHECK (((state)::text = ANY (ARRAY[('open'::character varying)::text, ('finalized'::character varying)::text])))
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
    created_at timestamp(6) without time zone NOT NULL,
    finalized_at timestamp(6) without time zone NOT NULL,
    manifest_sha256 character varying(64) NOT NULL,
    number bigint NOT NULL,
    site_id bigint NOT NULL,
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
    audience character varying NOT NULL,
    consumed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    grant_id bigint NOT NULL,
    invitation_id bigint NOT NULL,
    nonce_digest character varying(64) NOT NULL,
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
    created_at timestamp(6) without time zone NOT NULL,
    current_release_id bigint,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
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
-- Name: manifest_entries shortbread_immutable_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER shortbread_immutable_update BEFORE UPDATE ON public.manifest_entries FOR EACH ROW EXECUTE FUNCTION public.shortbread_reject_immutable_row_update();


--
-- Name: release_rollbacks shortbread_immutable_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER shortbread_immutable_update BEFORE UPDATE ON public.release_rollbacks FOR EACH ROW EXECUTE FUNCTION public.shortbread_reject_immutable_row_update();


--
-- Name: releases shortbread_immutable_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER shortbread_immutable_update BEFORE UPDATE ON public.releases FOR EACH ROW EXECUTE FUNCTION public.shortbread_reject_immutable_row_update();


--
-- Name: releases shortbread_monotonic_release_number; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER shortbread_monotonic_release_number BEFORE INSERT ON public.releases FOR EACH ROW EXECUTE FUNCTION public.shortbread_enforce_monotonic_release_number();


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
('20260720121000'),
('20260719145000'),
('20260719144000'),
('20260719143000'),
('20260719142000'),
('20260719141000'),
('20260719140000');

