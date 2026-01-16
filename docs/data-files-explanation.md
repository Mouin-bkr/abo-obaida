# Data Files Explanation

## Pipeline Flow

```
collect-gaza-videos.py (YouTube API v3)
    ↓
gaza_videos.json (988K)          ← Raw collection: JSON array format
    ↓ (conversion to JSONL)
gaza_videos.jsonl (678K)         ← Line-delimited for Spark
    ↓ (PySpark processing)
gaza_full_results.csv (71K)      ← Processed output with metrics
```

## File Purposes

### 1. gaza_videos.json (988K)
- **Format**: JSON array `[{...}, {...}, ...]`
- **Purpose**: Raw collection from YouTube Data API v3
- **Columns**: video_id, title, description, channel, published_at, view_count, like_count, comment_count, duration
- **Records**: 575 videos
- **Keep**: YES - Original raw data source

### 2. gaza_videos.jsonl (678K)
- **Format**: JSON Lines (one JSON object per line)
- **Purpose**: Spark-optimized format for distributed processing
- **Why smaller?**: Removed outer array brackets and whitespace
- **Keep**: YES - Required for PySpark pipeline input

### 3. gaza_full_results.csv (71K)
- **Format**: CSV with headers
- **Purpose**: Final processed output with basic metrics
- **Columns**: title, channel, views, likes, comments
- **Keep**: YES - Final deliverable output

## Conclusion

**No duplicates to remove.** Each file serves a distinct purpose in the data pipeline:
1. Raw collection (JSON)
2. Spark input (JSONL)
3. Processed output (CSV)
