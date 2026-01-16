# HDFS Operations Guide

## Overview

This guide covers essential HDFS commands for the Gaza YouTube Analytics project. All commands should be executed from inside the NameNode container or using `docker exec namenode <command>`.

## Quick Reference

### Access HDFS Shell
```bash
# From host machine
docker exec -it namenode bash

# Inside container, HDFS commands are available directly
hdfs dfs -ls /
```

---

## 1. Basic File Operations

### List Directory Contents
```bash
# List root directory
hdfs dfs -ls /

# List with human-readable sizes
hdfs dfs -ls -h /data

# Recursive listing
hdfs dfs -ls -R /data
```

### Create Directories
```bash
# Create single directory
hdfs dfs -mkdir /data

# Create nested directories
hdfs dfs -mkdir -p /data/raw/videos

# Verify creation
hdfs dfs -ls /data
```

### Upload Files
```bash
# Upload single file
hdfs dfs -put local_file.txt /data/

# Upload directory
hdfs dfs -put -f local_dir/ /data/

# Upload with overwrite
hdfs dfs -put -f existing_file.txt /data/
```

**Example for project:**
```bash
# Upload Gaza data to HDFS
hdfs dfs -mkdir -p /data/raw
hdfs dfs -put gaza_videos.jsonl /data/raw/
hdfs dfs -ls -h /data/raw/
```

### Download Files
```bash
# Download single file
hdfs dfs -get /data/results.csv ./

# Download entire directory
hdfs dfs -get /data/processed ./local_dir/

# Download and merge files
hdfs dfs -getmerge /data/output/* merged_output.txt
```

### Read File Contents
```bash
# Display entire file (small files only)
hdfs dfs -cat /data/sample.txt

# Display first 10 lines
hdfs dfs -cat /data/large_file.csv | head -10

# Display last 1KB
hdfs dfs -tail /data/log_file.txt
```

### Delete Files/Directories
```bash
# Delete file
hdfs dfs -rm /data/old_file.txt

# Delete directory recursively
hdfs dfs -rm -r /data/temp/

# Force delete (skip trash)
hdfs dfs -rm -r -skipTrash /data/old/
```

---

## 2. Advanced Operations

### Check Replication Factor
```bash
# View replication for all files in directory
hdfs fsck /data -files -blocks -locations

# View replication for specific file
hdfs fsck /data/raw/gaza_videos.jsonl -files -blocks -locations
```

**Expected Output:**
```
/data/raw/gaza_videos.jsonl:
 Total size:    678000 B
 Total blocks (validated):  1 (avg. block size 678000 B)
 Minimally replicated blocks:   1 (100.0 %)
 Over-replicated blocks:    0 (0.0 %)
 Under-replicated blocks:   0 (0.0 %)
```

### Change Replication Factor
```bash
# Set replication to 3 for specific file
hdfs dfs -setrep 3 /data/important_file.txt

# Set replication recursively for directory
hdfs dfs -setrep -R 2 /data/raw/

# Wait for replication to complete
hdfs dfs -setrep -w 3 /data/critical.csv
```

**Project Default:** Replication factor = 2 (configured in hdfs-site.xml)

### Disk Usage
```bash
# Check size of directory
hdfs dfs -du -h /data

# Summary of directory size
hdfs dfs -du -s -h /data

# Include replication in calculation
hdfs dfs -count -q -h /data
```

### File Permissions
```bash
# Check permissions
hdfs dfs -ls -l /data

# Change permissions (chmod style)
hdfs dfs -chmod 755 /data/public_file.txt

# Change ownership
hdfs dfs -chown root:supergroup /data/file.txt

# Recursive permission change
hdfs dfs -chmod -R 644 /data/readonly/
```

---

## 3. Cluster Administration

### HDFS Report
```bash
# Full cluster health report
hdfs dfsadmin -report

# Summary only
hdfs dfsadmin -report | grep -A 5 "Live datanodes"
```

**Key Metrics:**
- Configured Capacity: 930.55 GB
- Present Capacity: ~374 GB per DataNode
- DFS Used: 136 KB
- DFS Remaining: >900 GB
- Live DataNodes: 4

### Safe Mode Operations
```bash
# Check if in safe mode
hdfs dfsadmin -safemode get

# Enter safe mode (maintenance)
hdfs dfsadmin -safemode enter

# Leave safe mode
hdfs dfsadmin -safemode leave

# Wait for safe mode to exit automatically
hdfs dfsadmin -safemode wait
```

**Note:** NameNode enters safe mode on startup until 99.9% of blocks are reported.

### DataNode Status
```bash
# List all DataNodes
hdfs dfsadmin -report | grep "^Name:"

# Check specific DataNode
hdfs dfsadmin -getDatanodeInfo datanode1:9866
```

---

## 4. Block Management

### View Block Information
```bash
# File system check with block details
hdfs fsck / -files -blocks -locations

# Find blocks for specific file
hdfs fsck /data/raw/gaza_videos.jsonl -blocks -locations

# Find corrupt blocks
hdfs fsck / -list-corruptfileblocks
```

### Block Size Configuration
```bash
# Default block size: 128 MB (configured in hdfs-site.xml)
# View block size for file
hdfs fsck /data/large_file.csv -files | grep "Block size:"

# Upload with custom block size (128 MB example)
hdfs dfs -D dfs.blocksize=134217728 -put large_dataset.csv /data/
```

---

## 5. Trash Management

### Enable Trash (if not configured)
```bash
# Files deleted via -rm go to /user/<username>/.Trash/
hdfs dfs -rm /data/deleteme.txt

# View trash contents
hdfs dfs -ls /user/root/.Trash/Current

# Restore from trash
hdfs dfs -mv /user/root/.Trash/Current/data/deleteme.txt /data/

# Empty trash manually
hdfs dfs -expunge
```

---

## 6. Project-Specific Workflows

### Full Data Pipeline

```bash
# 1. Create directory structure
hdfs dfs -mkdir -p /data/raw
hdfs dfs -mkdir -p /data/processed
hdfs dfs -mkdir -p /data/output

# 2. Upload raw data
hdfs dfs -put gaza_videos.jsonl /data/raw/

# 3. Verify upload
hdfs dfs -ls -h /data/raw/
hdfs fsck /data/raw/gaza_videos.jsonl -files -blocks

# 4. Check replication (should be 2)
hdfs fsck /data/raw/ -files -blocks -locations | grep "replication"

# 5. Run Spark job (from spark-master)
spark-submit --master spark://spark-master:7077 /app/pyspark_gaza.py

# 6. Verify output
hdfs dfs -ls -h /data/processed/
hdfs dfs -cat /data/processed/results.csv | head -20

# 7. Download results
hdfs dfs -get /data/processed/gaza_results.csv ./
```

### Replication Verification Test

```bash
#!/bin/bash
# Test script: tests/hdfs-replication-test.sh

echo "=== HDFS Replication Test ==="

# Create test file
echo "Testing replication with 575 video records" > /tmp/test_replication.txt

# Upload with replication=2
hdfs dfs -put -f /tmp/test_replication.txt /tmp/

# Check block locations
echo "Block locations for test file:"
hdfs fsck /tmp/test_replication.txt -files -blocks -locations

# Verify replication count
REP_COUNT=$(hdfs fsck /tmp/test_replication.txt -files -blocks -locations | grep -oP "Live_repl=\K\d+")
echo "Replication count: $REP_COUNT"

if [ "$REP_COUNT" -eq 2 ]; then
    echo "✅ Replication test PASSED (expected=2, actual=$REP_COUNT)"
else
    echo "❌ Replication test FAILED (expected=2, actual=$REP_COUNT)"
fi

# Cleanup
hdfs dfs -rm /tmp/test_replication.txt
```

---

## 7. Troubleshooting

### Problem: HDFS capacity shows 0
**Solution:** Check volume mounts in docker-compose.yml. Ensure configs mount to `/usr/local/hadoop/etc/hadoop/`.

### Problem: DataNodes not registering
**Symptoms:**
```
hdfs dfsadmin -report
Live datanodes (0):
```

**Solutions:**
1. Check DataNode logs: `make logs S=datanode1`
2. Verify network connectivity: `docker exec datanode1 ping namenode`
3. Check `fs.defaultFS` in core-site.xml matches NameNode hostname
4. Restart cluster: `make reset`

### Problem: Safe mode stuck
**Solution:**
```bash
# Force leave safe mode
hdfs dfsadmin -safemode leave

# Or wait for block reports
hdfs dfsadmin -safemode wait
```

### Problem: Replication under-target
**Solution:**
```bash
# Find under-replicated blocks
hdfs fsck / -list-corruptfileblocks

# Force re-replication
hdfs dfs -setrep -R -w 2 /data/
```

---

## 8. Web UI Access

### NameNode UI
- **URL:** http://localhost:9870
- **Features:**
  - Overview: cluster capacity, DataNode status
  - Datanodes: live/dead nodes, disk usage
  - Browse the filesystem: navigate HDFS directories
  - Utilities: logs, metrics, JMX

### DataNode UIs
- **DataNode 1:** http://localhost:9864
- **DataNode 2:** http://localhost:9865
- **DataNode 3:** http://localhost:9866
- **DataNode 4:** http://localhost:9867

### Useful UI Endpoints
- **File Browser:** http://localhost:9870/explorer.html#/
- **DataNode Info:** http://localhost:9870/dfshealth.html#tab-datanode
- **Logs:** http://localhost:9870/logs/

---

## 9. Performance Tips

### Parallel Uploads
```bash
# Use multiple threads for large datasets
hdfs dfs -put -p 4 large_directory/ /data/

# Or use distcp for massive transfers
hadoop distcp /local/path hdfs://namenode:9000/data/
```

### Efficient Reading
```bash
# Read specific byte range
hdfs dfs -cat /data/file.txt | head -c 1000

# Use Spark for large file processing instead of cat
```

### Monitoring
```bash
# Watch DataNode space in real-time
watch -n 5 'hdfs dfsadmin -report | grep -A 3 "Live datanodes"'
```

---

## 10. Makefile Integration

All HDFS commands can be wrapped in Makefile targets for convenience:

```makefile
# Example additions to Makefile

test-replication:
	@echo "=== Testing HDFS Replication ==="
	docker exec namenode bash -c 'hdfs fsck /data/raw -files -blocks -locations | grep "replication"'

check-capacity:
	@echo "=== HDFS Capacity Report ==="
	docker exec namenode hdfs dfs -df -h /

list-data:
	@echo "=== HDFS Data Directory ==="
	docker exec namenode hdfs dfs -ls -h -R /data
```

**Usage:**
```bash
make test-replication
make check-capacity
make list-data
```

---

## References

- [Hadoop HDFS Commands Guide](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/HDFSCommands.html)
- [HDFS Architecture](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/HdfsDesign.html)
- Project README: [README.md](../README.md)
- Project Report: [REPORT.md](../REPORT.md)
