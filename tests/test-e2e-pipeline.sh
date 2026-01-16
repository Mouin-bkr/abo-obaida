#!/bin/bash
###############################################################################
# End-to-End Analytics Pipeline Test
# Tests the full data flow: Collection → HDFS → PySpark → Output
###############################################################################

set -e

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     Gaza YouTube Analytics - End-to-End Pipeline Test           ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# Check cluster health
echo "1️⃣  Checking cluster health..."
if ! docker exec namenode hdfs dfs -ls / &>/dev/null; then
    echo "❌ HDFS not accessible!"
    exit 1
fi
echo "   ✅ HDFS accessible"

if ! docker ps | grep -q spark-master; then
    echo "❌ Spark master not running!"
    exit 1
fi
echo "   ✅ Spark master running"

# Create HDFS directory structure
echo ""
echo "2️⃣  Creating HDFS directories..."
docker exec namenode hdfs dfs -mkdir -p /data/raw/youtube
docker exec namenode hdfs dfs -mkdir -p /data/processed
echo "   ✅ Directories created"

# Upload data to HDFS
echo ""
echo "3️⃣  Uploading data to HDFS..."
if [ ! -f gaza_videos.jsonl ]; then
    echo "❌ gaza_videos.jsonl not found!"
    echo "   Trying to create from gaza_videos.json..."
    if [ -f gaza_videos.json ]; then
        python3 << 'PYTHON_EOF'
import json
with open('gaza_videos.json', 'r') as f:
    videos = json.load(f)
with open('gaza_videos.jsonl', 'w') as f:
    for video in videos:
        f.write(json.dumps(video) + '\n')
print(f"✅ Created gaza_videos.jsonl with {len(videos)} records")
PYTHON_EOF
    else
        echo "❌ gaza_videos.json also not found!"
        exit 1
    fi
fi

docker exec -i namenode hdfs dfs -put -f gaza_videos.jsonl /data/raw/youtube/
echo "   ✅ Data uploaded"

# Verify upload
echo ""
echo "4️⃣  Verifying upload..."
SIZE=$(docker exec namenode hdfs dfs -du -h /data/raw/youtube/gaza_videos.jsonl | awk '{print $1" "$2}')
echo "   ✅ File size in HDFS: $SIZE"

# Show sample records
echo ""
echo "5️⃣  Sample data (first 3 records)..."
docker exec namenode hdfs dfs -cat /data/raw/youtube/gaza_videos.jsonl | head -3
echo ""

# Run PySpark job (simplified version for testing)
echo "6️⃣  Running PySpark analysis..."
cat > /tmp/simple_pyspark_test.py << 'PYSPARK_EOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, avg, sum as _sum

# Initialize Spark
spark = SparkSession.builder \
    .appName("Gaza_Analytics_Test") \
    .getOrCreate()

# Read data from HDFS
df = spark.read.json("hdfs://namenode:9000/data/raw/youtube/gaza_videos.jsonl")

print("=" * 70)
print("SCHEMA:")
df.printSchema()

print("=" * 70)
print("RECORD COUNT:")
total_records = df.count()
print(f"Total videos: {total_records}")

print("=" * 70)
print("TOP 5 VIDEOS BY VIEWS:")
df.select("title", "channel", "view_count", "like_count") \
  .orderBy(col("view_count").cast("long").desc()) \
  .show(5, truncate=50)

print("=" * 70)
print("CHANNEL STATISTICS:")
df.groupBy("channel") \
  .agg(
      count("*").alias("videos"),
      _sum(col("view_count").cast("long")).alias("total_views"),
      avg(col("like_count").cast("long")).alias("avg_likes")
  ) \
  .orderBy(col("total_views").desc()) \
  .show(10, truncate=30)

print("=" * 70)
print("SAVING RESULTS TO HDFS...")

# Save as CSV
output_path = "hdfs://namenode:9000/data/processed/gaza_results"
df.select("video_id", "title", "channel", "view_count", "like_count", "comment_count") \
  .write.mode("overwrite").csv(output_path, header=True)

print(f"✅ Results saved to: {output_path}")
print("=" * 70)

spark.stop()
PYSPARK_EOF

# Copy script to Spark master
docker cp /tmp/simple_pyspark_test.py spark-master:/tmp/

# Run Spark job
docker exec spark-master /opt/spark/bin/spark-submit \
    --master spark://spark-master:7077 \
    /tmp/simple_pyspark_test.py

echo ""
echo "7️⃣  Verifying output..."
docker exec namenode hdfs dfs -ls -h /data/processed/gaza_results
echo "   ✅ Output files created"

echo ""
echo "8️⃣  Sample output (first 5 lines)..."
docker exec namenode hdfs dfs -cat /data/processed/gaza_results/*.csv | head -5

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    ✅ PIPELINE TEST COMPLETE                     ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Summary:"
echo "   • Data ingested to HDFS: /data/raw/youtube/gaza_videos.jsonl"
echo "   • PySpark analysis completed"
echo "   • Results saved to: /data/processed/gaza_results/"
echo ""
echo "🔍 Next steps:"
echo "   • View results: docker exec namenode hdfs dfs -cat /data/processed/gaza_results/*.csv | less"
echo "   • Download results: docker exec namenode hdfs dfs -get /data/processed/gaza_results ./results/"
echo "   • Run Jupyter: jupyter notebook gaza_dashboard.ipynb"
