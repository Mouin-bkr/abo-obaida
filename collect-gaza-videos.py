import googleapiclient.discovery
import json
import time
from datetime import datetime, timedelta

API_KEY = "AIzaSyCtPeuVHiK-nlJh04QABzD26FJWhcRZfgU"  
youtube = googleapiclient.discovery.build("youtube", "v3", developerKey=API_KEY)

def collect_videos(query, max_results=200):
    videos = []
    next_page_token = None
    
    while len(videos) < max_results:
        search_response = youtube.search().list(
            q=query,
            part="snippet",
            maxResults=50,
            pageToken=next_page_token,
            type="video",
            order="viewCount",
            publishedAfter="2023-10-07T00:00:00Z"  # Gaza genocide start date
        ).execute()
        
        for item in search_response["items"]:
            video_id = item["id"]["videoId"]
            video_details = youtube.videos().list(
                part="snippet,statistics,contentDetails",
                id=video_id
            ).execute()["items"][0]
            
            videos.append({
                "video_id": video_id,
                "title": video_details["snippet"]["title"],
                "description": video_details["snippet"]["description"],
                "channel": video_details["snippet"]["channelTitle"],
                "published_at": video_details["snippet"]["publishedAt"],
                "view_count": video_details["statistics"].get("viewCount", 0),
                "like_count": video_details["statistics"].get("likeCount", 0),
                "comment_count": video_details["statistics"].get("commentCount", 0),
                "duration": video_details["contentDetails"]["duration"]
            })
        
        next_page_token = search_response.get("nextPageToken")
        if not next_page_token:
            break
        time.sleep(1)  # Rate limiting
    
    return videos[:max_results]

# Collect data
# ============================================
# ORIGINAL EXAM QUERIES (COMMENTED OUT)
# ============================================
queries = [
#     English
     "Gaza war", "Palestine Israel", "Gaza Palestine", "Israel Hamas",
#     # Arabic
     "غزة", "فلسطين إسرائيل", "حرب غزة", "القدس فلسطين",
#     # Spanish
     "guerra de Gaza", "Palestina Israel", "conflicto Gaza", "Palestina"
 ]

# ============================================
# ABU OBEIDA ANALYSIS - Multi-language Queries
# Focus: Global perspectives on Abu Obeida (Palestinian spokesperson)
# ============================================


all_videos = []

for query in queries:
    print(f"Collecting '{query}'...")
    videos = collect_videos(query, max_results=50)
    all_videos.extend(videos)
    time.sleep(2)

# Save to JSON
with open("abu_obeida_videos.json", "w", encoding='utf-8') as f:
    json.dump(all_videos, f, indent=2, ensure_ascii=False)

print(f"Collected {len(all_videos)} videos about Abu Obeida → abu_obeida_videos.json")
