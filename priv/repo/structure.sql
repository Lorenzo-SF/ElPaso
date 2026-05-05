--
-- PostgreSQL database dump
--

\restrict 7wqCyv9wgkHi9pk8dO6X5LqySGXss0ItwzsqhJoXsZ1503L4lDt7O7Nd86gxcf2

-- Dumped from database version 17.9 (Debian 17.9-1.pgdg13+1)
-- Dumped by pg_dump version 18.3

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: api_usage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_usage (
    user_id character varying(255) NOT NULL,
    model_id character varying(255) NOT NULL,
    date date NOT NULL,
    input_tokens bigint DEFAULT 0,
    output_tokens bigint DEFAULT 0,
    cost_usd numeric(10,6),
    request_count integer DEFAULT 0,
    inserted_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: auto_tune_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auto_tune_runs (
    applied integer NOT NULL,
    changes jsonb,
    trigger character varying(255) DEFAULT 'scheduled'::character varying,
    inserted_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: conversation_summaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversation_summaries (
    session_id character varying(255) NOT NULL,
    summary text NOT NULL,
    summary_tokens integer,
    window_start timestamp(0) without time zone,
    window_end timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    session_id character varying(255) NOT NULL,
    role character varying(255) NOT NULL,
    content text NOT NULL,
    model_id character varying(255),
    tokens integer,
    inserted_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: model_pricing; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.model_pricing (
    model_id character varying(255) NOT NULL,
    input_price_per_1k numeric(10,6) NOT NULL,
    output_price_per_1k numeric(10,6) NOT NULL,
    valid_from date NOT NULL,
    valid_until date,
    inserted_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: routing_decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.routing_decisions (
    request_id character varying(255) NOT NULL,
    session_id character varying(255) NOT NULL,
    model_id character varying(255) NOT NULL,
    task_type character varying(255) NOT NULL,
    selected_model character varying(255) NOT NULL,
    runner_up character varying(255),
    token_estimate integer,
    complexity_score double precision,
    language character varying(255),
    scores jsonb,
    reason character varying(255),
    outcome character varying(255),
    latency_ms integer,
    decision_latency_us integer,
    decided_at timestamp(0) without time zone NOT NULL,
    inserted_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    session_id character varying(255) NOT NULL,
    user_id character varying(255),
    model_id character varying(255),
    context_mode character varying(255) DEFAULT 'transparent'::character varying,
    status character varying(255) DEFAULT 'active'::character varying,
    inserted_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: sessions_shared; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions_shared (
    session_id character varying(255) NOT NULL,
    node character varying(255) NOT NULL,
    last_accessed_at timestamp(0) without time zone NOT NULL,
    inserted_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: api_usage_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_usage_date_index ON public.api_usage USING btree (date);


--
-- Name: api_usage_model_id_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_usage_model_id_date_index ON public.api_usage USING btree (model_id, date);


--
-- Name: api_usage_user_id_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_usage_user_id_date_index ON public.api_usage USING btree (user_id, date);


--
-- Name: api_usage_user_id_model_id_date_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX api_usage_user_id_model_id_date_index ON public.api_usage USING btree (user_id, model_id, date);


--
-- Name: auto_tune_runs_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX auto_tune_runs_inserted_at_index ON public.auto_tune_runs USING btree (inserted_at);


--
-- Name: conversation_summaries_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversation_summaries_session_id_index ON public.conversation_summaries USING btree (session_id);


--
-- Name: conversation_summaries_window_end_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversation_summaries_window_end_index ON public.conversation_summaries USING btree (window_end);


--
-- Name: messages_inserted_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_inserted_at_index ON public.messages USING btree (inserted_at);


--
-- Name: messages_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX messages_session_id_index ON public.messages USING btree (session_id);


--
-- Name: model_pricing_model_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX model_pricing_model_id_index ON public.model_pricing USING btree (model_id);


--
-- Name: model_pricing_valid_from_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX model_pricing_valid_from_index ON public.model_pricing USING btree (valid_from);


--
-- Name: routing_decisions_decided_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX routing_decisions_decided_at_index ON public.routing_decisions USING btree (decided_at);


--
-- Name: routing_decisions_decided_at_outcome_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX routing_decisions_decided_at_outcome_index ON public.routing_decisions USING btree (decided_at, outcome);


--
-- Name: routing_decisions_model_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX routing_decisions_model_id_index ON public.routing_decisions USING btree (model_id);


--
-- Name: routing_decisions_model_id_task_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX routing_decisions_model_id_task_type_index ON public.routing_decisions USING btree (model_id, task_type);


--
-- Name: routing_decisions_outcome_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX routing_decisions_outcome_index ON public.routing_decisions USING btree (outcome);


--
-- Name: routing_decisions_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX routing_decisions_session_id_index ON public.routing_decisions USING btree (session_id);


--
-- Name: routing_decisions_task_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX routing_decisions_task_type_index ON public.routing_decisions USING btree (task_type);


--
-- Name: sessions_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_session_id_index ON public.sessions USING btree (session_id);


--
-- Name: sessions_shared_node_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_shared_node_index ON public.sessions_shared USING btree (node);


--
-- Name: sessions_shared_session_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_shared_session_id_index ON public.sessions_shared USING btree (session_id);


--
-- Name: sessions_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_status_index ON public.sessions USING btree (status);


--
-- Name: sessions_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_user_id_index ON public.sessions USING btree (user_id);


--
-- PostgreSQL database dump complete
--

\unrestrict 7wqCyv9wgkHi9pk8dO6X5LqySGXss0ItwzsqhJoXsZ1503L4lDt7O7Nd86gxcf2

INSERT INTO public."schema_migrations" (version) VALUES (20240421);
