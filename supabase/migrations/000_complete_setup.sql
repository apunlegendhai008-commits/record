-- Complete Supabase Setup for GoOnDVR
-- Run this entire file in your Supabase SQL Editor
-- This will create all necessary tables for video uploads and channel persistence

-- ============================================================================
-- 1. VIDEO UPLOADS TABLE (for storing uploaded video links)
-- ============================================================================

-- Create table for storing video upload records from multiple hosts
CREATE TABLE IF NOT EXISTS video_uploads (
    id SERIAL PRIMARY KEY,
    streamer_name TEXT NOT NULL,
    filename TEXT,
    gofile_link TEXT,
    turboviplay_link TEXT,
    voesx_link TEXT,
    streamtape_link TEXT,
    thumbnail_link TEXT,
    upload_date TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_video_uploads_streamer_name ON video_uploads(streamer_name);
CREATE INDEX IF NOT EXISTS idx_video_uploads_upload_date ON video_uploads(upload_date DESC);

-- Enable Row Level Security
ALTER TABLE video_uploads ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all operations
CREATE POLICY "Allow all operations on video_uploads" ON video_uploads
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Add comment
COMMENT ON TABLE video_uploads IS 'Stores video upload links from multiple hosting services (GoFile, TurboViPlay, VOE.sx, Streamtape)';

-- ============================================================================
-- 2. CHANNELS TABLE (for storing channel configurations)
-- ============================================================================

-- Create channels table to store channel configurations
CREATE TABLE IF NOT EXISTS channels (
    id SERIAL PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    site TEXT NOT NULL DEFAULT 'chaturbate',
    is_paused BOOLEAN NOT NULL DEFAULT false,
    framerate INTEGER NOT NULL DEFAULT 30,
    resolution INTEGER NOT NULL DEFAULT 1080,
    pattern TEXT NOT NULL,
    max_filesize INTEGER NOT NULL DEFAULT 0,
    created_at BIGINT NOT NULL,
    streamed_at BIGINT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_channels_username ON channels(username);
CREATE INDEX IF NOT EXISTS idx_channels_site ON channels(site);

-- Enable Row Level Security
ALTER TABLE channels ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all operations
CREATE POLICY "Allow all operations on channels" ON channels
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Add comment
COMMENT ON TABLE channels IS 'Stores channel configurations for the recorder';

-- ============================================================================
-- 3. APPLICATION SETTINGS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL DEFAULT '{}',
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations on app_settings" ON app_settings
    FOR ALL
    USING (true)
    WITH CHECK (true);

COMMENT ON TABLE app_settings IS 'Stores application settings (cookies, API keys, upload config, etc.)';

-- ============================================================================
-- 4. TUNNEL SESSIONS TABLE + CURRENT_TUNNEL VIEW
-- ============================================================================

CREATE TABLE IF NOT EXISTS tunnel_sessions (
    id BIGSERIAL PRIMARY KEY,
    run_id INTEGER,
    url TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tunnel_sessions_active ON tunnel_sessions(is_active, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_tunnel_sessions_run_id ON tunnel_sessions(run_id);

COMMENT ON TABLE tunnel_sessions IS 'Tracks Cloudflare tunnel URLs for accessing the recorder UI';
COMMENT ON COLUMN tunnel_sessions.run_id IS 'GitHub Actions run number (if applicable)';
COMMENT ON COLUMN tunnel_sessions.url IS 'The trycloudflare.com URL for accessing the UI';
COMMENT ON COLUMN tunnel_sessions.started_at IS 'When the tunnel was first established';
COMMENT ON COLUMN tunnel_sessions.last_seen_at IS 'Last time the tunnel was verified as active';
COMMENT ON COLUMN tunnel_sessions.is_active IS 'Whether this tunnel is currently active';

ALTER TABLE tunnel_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations on tunnel_sessions" ON tunnel_sessions
    FOR ALL
    USING (true)
    WITH CHECK (true);

CREATE OR REPLACE FUNCTION mark_old_tunnels_inactive()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE tunnel_sessions
    SET is_active = FALSE
    WHERE id != NEW.id AND is_active = TRUE;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_mark_old_tunnels_inactive ON tunnel_sessions;
CREATE TRIGGER trigger_mark_old_tunnels_inactive
    AFTER INSERT ON tunnel_sessions
    FOR EACH ROW
    EXECUTE FUNCTION mark_old_tunnels_inactive();

CREATE OR REPLACE VIEW current_tunnel AS
SELECT *
FROM tunnel_sessions
WHERE is_active = TRUE
ORDER BY started_at DESC
LIMIT 1;

COMMENT ON VIEW current_tunnel IS 'Returns the currently active tunnel URL';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Run these to verify tables were created successfully:
-- SELECT COUNT(*) as video_uploads_count FROM video_uploads;
-- SELECT COUNT(*) as channels_count FROM channels;
-- SELECT * FROM video_uploads ORDER BY upload_date DESC LIMIT 10;
-- SELECT * FROM channels ORDER BY created_at DESC LIMIT 10;
