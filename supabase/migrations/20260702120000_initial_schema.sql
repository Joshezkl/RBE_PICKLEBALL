-- RBE (Rosales Pickleball Club) — initial PostgreSQL schema for Supabase
-- Converted from Laravel MySQL migrations (backend/database/migrations/)
--
-- Apply with: supabase db push   OR   paste into Supabase SQL Editor
-- Laravel continues to use this database via DB_CONNECTION=pgsql

-- ---------------------------------------------------------------------------
-- Laravel infrastructure
-- ---------------------------------------------------------------------------

CREATE TABLE migrations (
    id BIGSERIAL PRIMARY KEY,
    migration VARCHAR(255) NOT NULL,
    batch INTEGER NOT NULL
);

CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    email_verified_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    password VARCHAR(255) NOT NULL,
    remember_token VARCHAR(100) NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT users_email_unique UNIQUE (email)
);

CREATE TABLE password_reset_tokens (
    email VARCHAR(255) PRIMARY KEY,
    token VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL
);

CREATE TABLE sessions (
    id VARCHAR(255) PRIMARY KEY,
    user_id BIGINT NULL,
    ip_address VARCHAR(45) NULL,
    user_agent TEXT NULL,
    payload TEXT NOT NULL,
    last_activity INTEGER NOT NULL
);

CREATE INDEX sessions_user_id_index ON sessions (user_id);
CREATE INDEX sessions_last_activity_index ON sessions (last_activity);

CREATE TABLE cache (
    key VARCHAR(255) PRIMARY KEY,
    value TEXT NOT NULL,
    expiration INTEGER NOT NULL
);

CREATE INDEX cache_expiration_index ON cache (expiration);

CREATE TABLE cache_locks (
    key VARCHAR(255) PRIMARY KEY,
    owner VARCHAR(255) NOT NULL,
    expiration INTEGER NOT NULL
);

CREATE INDEX cache_locks_expiration_index ON cache_locks (expiration);

CREATE TABLE jobs (
    id BIGSERIAL PRIMARY KEY,
    queue VARCHAR(255) NOT NULL,
    payload TEXT NOT NULL,
    attempts SMALLINT NOT NULL,
    reserved_at INTEGER NULL,
    available_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE INDEX jobs_queue_index ON jobs (queue);

CREATE TABLE job_batches (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    total_jobs INTEGER NOT NULL,
    pending_jobs INTEGER NOT NULL,
    failed_jobs INTEGER NOT NULL,
    failed_job_ids TEXT NOT NULL,
    options TEXT NULL,
    cancelled_at INTEGER NULL,
    created_at INTEGER NOT NULL,
    finished_at INTEGER NULL
);

CREATE TABLE failed_jobs (
    id BIGSERIAL PRIMARY KEY,
    uuid VARCHAR(255) NOT NULL,
    connection TEXT NOT NULL,
    queue TEXT NOT NULL,
    payload TEXT NOT NULL,
    exception TEXT NOT NULL,
    failed_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT failed_jobs_uuid_unique UNIQUE (uuid)
);

-- ---------------------------------------------------------------------------
-- Play sessions (queue / court management)
-- ---------------------------------------------------------------------------

CREATE TABLE play_sessions (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    status VARCHAR(255) NOT NULL DEFAULT 'active',
    check_in_token VARCHAR(64) NULL,
    play_format VARCHAR(255) NOT NULL DEFAULT 'doubles',
    match_mode VARCHAR(32) NOT NULL DEFAULT 'auto_balanced',
    match_mode_settings JSONB NULL,
    court_count SMALLINT NOT NULL DEFAULT 4,
    auto_assign_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    require_payment BOOLEAN NOT NULL DEFAULT FALSE,
    session_fee_cents INTEGER NOT NULL DEFAULT 3000,
    next_court_queue VARCHAR(255) NOT NULL DEFAULT 'winner',
    next_new_player_queue VARCHAR(255) NOT NULL DEFAULT 'winner',
    new_players_joined_count INTEGER NOT NULL DEFAULT 0,
    started_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    ended_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    report_data JSONB NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT play_sessions_status_check
        CHECK (status IN ('active', 'ended')),
    CONSTRAINT play_sessions_play_format_check
        CHECK (play_format IN ('doubles', 'singles')),
    CONSTRAINT play_sessions_next_court_queue_check
        CHECK (next_court_queue IN ('winner', 'loser')),
    CONSTRAINT play_sessions_next_new_player_queue_check
        CHECK (next_new_player_queue IN ('winner', 'loser')),
    CONSTRAINT play_sessions_check_in_token_unique UNIQUE (check_in_token)
);

CREATE INDEX play_sessions_status_index ON play_sessions (status);
CREATE INDEX play_sessions_started_at_index ON play_sessions (started_at);
CREATE INDEX play_sessions_ended_at_index ON play_sessions (ended_at);

CREATE TABLE club_players (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    skill_level VARCHAR(20) NOT NULL DEFAULT 'beginner',
    gender VARCHAR(10) NULL,
    is_guest BOOLEAN NOT NULL DEFAULT FALSE,
    is_tournament_only BOOLEAN NOT NULL DEFAULT FALSE,
    display_name VARCHAR(255) NULL,
    total_matches INTEGER NOT NULL DEFAULT 0,
    total_wins INTEGER NOT NULL DEFAULT 0,
    total_losses INTEGER NOT NULL DEFAULT 0,
    total_points_scored INTEGER NOT NULL DEFAULT 0,
    total_points_allowed INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL
);

CREATE TABLE players (
    id BIGSERIAL PRIMARY KEY,
    play_session_id BIGINT NOT NULL,
    club_player_id BIGINT NULL,
    name VARCHAR(255) NOT NULL,
    skill_level VARCHAR(20) NULL,
    gender VARCHAR(10) NULL,
    last_partner_id BIGINT NULL,
    partner_phase VARCHAR(255) NOT NULL DEFAULT 'together',
    wins INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    availability VARCHAR(255) NOT NULL DEFAULT 'active',
    away_queue_type VARCHAR(255) NULL,
    away_queue_position INTEGER NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT players_play_session_id_name_unique UNIQUE (play_session_id, name),
    CONSTRAINT players_partner_phase_check
        CHECK (partner_phase IN ('together', 'split_next')),
    CONSTRAINT players_play_session_id_foreign
        FOREIGN KEY (play_session_id) REFERENCES play_sessions (id) ON DELETE CASCADE,
    CONSTRAINT players_club_player_id_foreign
        FOREIGN KEY (club_player_id) REFERENCES club_players (id) ON DELETE SET NULL,
    CONSTRAINT players_last_partner_id_foreign
        FOREIGN KEY (last_partner_id) REFERENCES players (id) ON DELETE SET NULL
);

CREATE INDEX players_session_availability_index ON players (play_session_id, availability);

CREATE TABLE courts (
    id BIGSERIAL PRIMARY KEY,
    play_session_id BIGINT NOT NULL,
    court_number SMALLINT NOT NULL,
    skill_bracket VARCHAR(20) NULL,
    is_challenge_court BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(255) NOT NULL DEFAULT 'available',
    current_match_id BIGINT NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT courts_play_session_id_court_number_unique UNIQUE (play_session_id, court_number),
    CONSTRAINT courts_status_check
        CHECK (status IN ('available', 'in_match', 'waiting_result')),
    CONSTRAINT courts_play_session_id_foreign
        FOREIGN KEY (play_session_id) REFERENCES play_sessions (id) ON DELETE CASCADE
);

CREATE TABLE matches (
    id BIGSERIAL PRIMARY KEY,
    play_session_id BIGINT NOT NULL,
    court_id BIGINT NOT NULL,
    team_a_player1 BIGINT NOT NULL,
    team_a_player2 BIGINT NULL,
    team_b_player1 BIGINT NOT NULL,
    team_b_player2 BIGINT NULL,
    score_a SMALLINT NULL,
    score_b SMALLINT NULL,
    winner_team VARCHAR(255) NULL,
    status VARCHAR(255) NOT NULL DEFAULT 'in_match',
    is_challenge_court BOOLEAN NOT NULL DEFAULT FALSE,
    started_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT matches_winner_team_check
        CHECK (winner_team IN ('A', 'B')),
    CONSTRAINT matches_status_check
        CHECK (status IN ('in_match', 'waiting_result', 'finished')),
    CONSTRAINT matches_play_session_id_foreign
        FOREIGN KEY (play_session_id) REFERENCES play_sessions (id) ON DELETE CASCADE,
    CONSTRAINT matches_court_id_foreign
        FOREIGN KEY (court_id) REFERENCES courts (id) ON DELETE CASCADE,
    CONSTRAINT matches_team_a_player1_foreign
        FOREIGN KEY (team_a_player1) REFERENCES players (id),
    CONSTRAINT matches_team_a_player2_foreign
        FOREIGN KEY (team_a_player2) REFERENCES players (id),
    CONSTRAINT matches_team_b_player1_foreign
        FOREIGN KEY (team_b_player1) REFERENCES players (id),
    CONSTRAINT matches_team_b_player2_foreign
        FOREIGN KEY (team_b_player2) REFERENCES players (id)
);

CREATE INDEX matches_play_session_id_status_index ON matches (play_session_id, status);
CREATE INDEX matches_play_session_id_finished_at_index ON matches (play_session_id, finished_at);

ALTER TABLE courts
    ADD CONSTRAINT courts_current_match_id_foreign
        FOREIGN KEY (current_match_id) REFERENCES matches (id) ON DELETE SET NULL;

CREATE TABLE queues (
    id BIGSERIAL PRIMARY KEY,
    play_session_id BIGINT NOT NULL,
    player_id BIGINT NOT NULL,
    queue_type VARCHAR(32) NOT NULL,
    position INTEGER NOT NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT queues_play_session_id_player_id_unique UNIQUE (play_session_id, player_id),
    CONSTRAINT queues_play_session_id_foreign
        FOREIGN KEY (play_session_id) REFERENCES play_sessions (id) ON DELETE CASCADE,
    CONSTRAINT queues_player_id_foreign
        FOREIGN KEY (player_id) REFERENCES players (id) ON DELETE CASCADE
);

CREATE INDEX queues_play_session_id_queue_type_position_index
    ON queues (play_session_id, queue_type, position);

CREATE TABLE session_players (
    id BIGSERIAL PRIMARY KEY,
    play_session_id BIGINT NOT NULL,
    club_player_id BIGINT NOT NULL,
    session_matches INTEGER NOT NULL DEFAULT 0,
    session_wins INTEGER NOT NULL DEFAULT 0,
    session_losses INTEGER NOT NULL DEFAULT 0,
    session_points_scored INTEGER NOT NULL DEFAULT 0,
    session_points_allowed INTEGER NOT NULL DEFAULT 0,
    payment_status VARCHAR(16) NOT NULL DEFAULT 'free',
    payment_amount_cents INTEGER NULL,
    payment_method VARCHAR(16) NULL,
    paid_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT session_players_play_session_id_club_player_id_unique
        UNIQUE (play_session_id, club_player_id),
    CONSTRAINT session_players_play_session_id_foreign
        FOREIGN KEY (play_session_id) REFERENCES play_sessions (id) ON DELETE CASCADE,
    CONSTRAINT session_players_club_player_id_foreign
        FOREIGN KEY (club_player_id) REFERENCES club_players (id) ON DELETE CASCADE
);

CREATE TABLE session_presets (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    match_mode VARCHAR(40) NOT NULL,
    play_format VARCHAR(10) NOT NULL DEFAULT 'doubles',
    court_count SMALLINT NOT NULL DEFAULT 4,
    auto_assign_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    match_mode_settings JSONB NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL
);

CREATE TABLE payments (
    id BIGSERIAL PRIMARY KEY,
    play_session_id BIGINT NOT NULL,
    club_player_id BIGINT NOT NULL,
    session_player_id BIGINT NULL,
    amount_cents INTEGER NOT NULL,
    method VARCHAR(16) NOT NULL DEFAULT 'cash',
    status VARCHAR(16) NOT NULL DEFAULT 'completed',
    recorded_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL,
    notes VARCHAR(255) NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT payments_play_session_id_foreign
        FOREIGN KEY (play_session_id) REFERENCES play_sessions (id) ON DELETE CASCADE,
    CONSTRAINT payments_club_player_id_foreign
        FOREIGN KEY (club_player_id) REFERENCES club_players (id) ON DELETE CASCADE,
    CONSTRAINT payments_session_player_id_foreign
        FOREIGN KEY (session_player_id) REFERENCES session_players (id) ON DELETE SET NULL
);

CREATE INDEX payments_play_session_id_recorded_at_index
    ON payments (play_session_id, recorded_at);
CREATE INDEX payments_club_player_id_recorded_at_index
    ON payments (club_player_id, recorded_at);

CREATE TABLE challenge_court_teams (
    id BIGSERIAL PRIMARY KEY,
    play_session_id BIGINT NOT NULL,
    player1_id BIGINT NOT NULL,
    player2_id BIGINT NULL,
    position INTEGER NOT NULL,
    status VARCHAR(16) NOT NULL DEFAULT 'queued',
    cc_wins SMALLINT NOT NULL DEFAULT 0,
    court_id BIGINT NULL,
    current_match_id BIGINT NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT challenge_court_teams_play_session_id_foreign
        FOREIGN KEY (play_session_id) REFERENCES play_sessions (id) ON DELETE CASCADE,
    CONSTRAINT challenge_court_teams_player1_id_foreign
        FOREIGN KEY (player1_id) REFERENCES players (id) ON DELETE CASCADE,
    CONSTRAINT challenge_court_teams_player2_id_foreign
        FOREIGN KEY (player2_id) REFERENCES players (id) ON DELETE SET NULL,
    CONSTRAINT challenge_court_teams_court_id_foreign
        FOREIGN KEY (court_id) REFERENCES courts (id) ON DELETE SET NULL,
    CONSTRAINT challenge_court_teams_current_match_id_foreign
        FOREIGN KEY (current_match_id) REFERENCES matches (id) ON DELETE SET NULL
);

CREATE INDEX challenge_court_teams_play_session_id_status_position_index
    ON challenge_court_teams (play_session_id, status, position);

CREATE TABLE session_partner_pairs (
    id BIGSERIAL PRIMARY KEY,
    play_session_id BIGINT NOT NULL,
    player_one_id BIGINT NOT NULL,
    player_two_id BIGINT NOT NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT session_partner_pairs_play_session_id_player_one_id_player_two_id_unique
        UNIQUE (play_session_id, player_one_id, player_two_id),
    CONSTRAINT session_partner_pairs_play_session_id_foreign
        FOREIGN KEY (play_session_id) REFERENCES play_sessions (id) ON DELETE CASCADE,
    CONSTRAINT session_partner_pairs_player_one_id_foreign
        FOREIGN KEY (player_one_id) REFERENCES players (id) ON DELETE CASCADE,
    CONSTRAINT session_partner_pairs_player_two_id_foreign
        FOREIGN KEY (player_two_id) REFERENCES players (id) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------------
-- Tournaments
-- ---------------------------------------------------------------------------

CREATE TABLE tournaments (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'draft',
    registration_token VARCHAR(64) NULL,
    advance_count SMALLINT NOT NULL DEFAULT 2,
    group_count SMALLINT NOT NULL DEFAULT 4,
    court_count SMALLINT NOT NULL DEFAULT 4,
    settings JSONB NULL,
    started_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    ended_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT tournaments_registration_token_unique UNIQUE (registration_token)
);

CREATE TABLE tournament_categories (
    id BIGSERIAL PRIMARY KEY,
    tournament_id BIGINT NOT NULL,
    category_key VARCHAR(96) NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    phase VARCHAR(32) NOT NULL DEFAULT 'setup',
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT tournament_categories_tournament_id_category_key_unique
        UNIQUE (tournament_id, category_key),
    CONSTRAINT tournament_categories_tournament_id_foreign
        FOREIGN KEY (tournament_id) REFERENCES tournaments (id) ON DELETE CASCADE
);

CREATE TABLE tournament_teams (
    id BIGSERIAL PRIMARY KEY,
    tournament_id BIGINT NOT NULL,
    tournament_category_id BIGINT NOT NULL,
    group_key VARCHAR(4) NULL,
    display_name VARCHAR(120) NOT NULL,
    seed SMALLINT NULL,
    status VARCHAR(24) NOT NULL DEFAULT 'active',
    wins SMALLINT NOT NULL DEFAULT 0,
    losses SMALLINT NOT NULL DEFAULT 0,
    points_scored SMALLINT NOT NULL DEFAULT 0,
    points_allowed SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT tournament_teams_tournament_id_foreign
        FOREIGN KEY (tournament_id) REFERENCES tournaments (id) ON DELETE CASCADE,
    CONSTRAINT tournament_teams_tournament_category_id_foreign
        FOREIGN KEY (tournament_category_id) REFERENCES tournament_categories (id) ON DELETE CASCADE
);

CREATE TABLE tournament_team_members (
    id BIGSERIAL PRIMARY KEY,
    tournament_team_id BIGINT NOT NULL,
    club_player_id BIGINT NOT NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT tournament_team_members_tournament_team_id_club_player_id_unique
        UNIQUE (tournament_team_id, club_player_id),
    CONSTRAINT tournament_team_members_tournament_team_id_foreign
        FOREIGN KEY (tournament_team_id) REFERENCES tournament_teams (id) ON DELETE CASCADE,
    CONSTRAINT tournament_team_members_club_player_id_foreign
        FOREIGN KEY (club_player_id) REFERENCES club_players (id) ON DELETE CASCADE
);

CREATE TABLE tournament_matches (
    id BIGSERIAL PRIMARY KEY,
    tournament_id BIGINT NOT NULL,
    tournament_category_id BIGINT NOT NULL,
    group_key VARCHAR(4) NULL,
    phase VARCHAR(32) NOT NULL,
    round_index SMALLINT NOT NULL DEFAULT 0,
    match_index SMALLINT NOT NULL DEFAULT 0,
    team_a_id BIGINT NULL,
    team_b_id BIGINT NULL,
    score_a SMALLINT NULL,
    score_b SMALLINT NULL,
    winner_team_id BIGINT NULL,
    feeds_into_match_id BIGINT NULL,
    feed_slot VARCHAR(8) NULL,
    status VARCHAR(24) NOT NULL DEFAULT 'scheduled',
    court_number SMALLINT NULL,
    created_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    updated_at TIMESTAMP(0) WITHOUT TIME ZONE NULL,
    CONSTRAINT tournament_matches_tournament_id_foreign
        FOREIGN KEY (tournament_id) REFERENCES tournaments (id) ON DELETE CASCADE,
    CONSTRAINT tournament_matches_tournament_category_id_foreign
        FOREIGN KEY (tournament_category_id) REFERENCES tournament_categories (id) ON DELETE CASCADE,
    CONSTRAINT tournament_matches_team_a_id_foreign
        FOREIGN KEY (team_a_id) REFERENCES tournament_teams (id) ON DELETE SET NULL,
    CONSTRAINT tournament_matches_team_b_id_foreign
        FOREIGN KEY (team_b_id) REFERENCES tournament_teams (id) ON DELETE SET NULL,
    CONSTRAINT tournament_matches_winner_team_id_foreign
        FOREIGN KEY (winner_team_id) REFERENCES tournament_teams (id) ON DELETE SET NULL,
    CONSTRAINT tournament_matches_feeds_into_match_id_foreign
        FOREIGN KEY (feeds_into_match_id) REFERENCES tournament_matches (id) ON DELETE SET NULL
);
