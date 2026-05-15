-- Add columns for additional video hosting services
ALTER TABLE gofile_uploads 
ADD COLUMN IF NOT EXISTS turboviplay_link TEXT,
ADD COLUMN IF NOT EXISTS voesx_link TEXT,
ADD COLUMN IF NOT EXISTS streamtape_link TEXT;

-- Rename table to reflect multi-host support
ALTER TABLE gofile_uploads RENAME TO video_uploads;

-- Update indexes
DROP INDEX IF EXISTS idx_gofile_uploads_streamer_name;
DROP INDEX IF EXISTS idx_gofile_uploads_upload_date;

CREATE INDEX IF NOT EXISTS idx_video_uploads_streamer_name ON video_uploads(streamer_name);
CREATE INDEX IF NOT EXISTS idx_video_uploads_upload_date ON video_uploads(upload_date DESC);

-- Add filename column for better tracking
ALTER TABLE video_uploads 
ADD COLUMN IF NOT EXISTS filename TEXT;

-- Add comment
COMMENT ON TABLE video_uploads IS 'Stores video upload links from multiple hosting services (GoFile, TurboViPlay, VOE.sx, Streamtape)';
