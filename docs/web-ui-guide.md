# Web UI Access Guide

## Overview

The Hadoop/Spark cluster exposes several web interfaces for monitoring and management. All UIs are accessible from the host machine via `localhost`.

---

## 1. NameNode Web UI

**URL:** http://localhost:9870

### Features:
- **Overview Tab:**
  - Cluster capacity summary
  - Live/dead DataNode count
  - HDFS usage statistics
  - Blocks summary (total, missing, corrupt)
  
- **Datanodes Tab:**
  - List of all DataNodes with status
  - Capacity per DataNode
  - Last contact time
  - Disk usage per node
  
- **Datanode Volume Failures:**
  - Failed volumes report
  
- **Snapshot:**
  - HDFS snapshot management
  
- **Startup Progress:**
  - NameNode initialization status
  
- **Utilities:**
  - Logs viewer
  - Configuration browser
  - JMX metrics endpoint

### Key Endpoints:
- File Browser: http://localhost:9870/explorer.html#/
- DataNode Health: http://localhost:9870/dfshealth.html#tab-datanode
- Logs: http://localhost:9870/logs/
- Configuration: http://localhost:9870/conf
- JMX Metrics: http://localhost:9870/jmx

### Expected Values (Healthy Cluster):
```
Configured Capacity: 930.55 GB
DFS Used: < 1 MB (fresh cluster)
DFS Remaining: > 900 GB
Live Nodes: 4
Dead Nodes: 0
Decommissioning Nodes: 0
```

---

## 2. YARN ResourceManager UI

**URL:** http://localhost:8088

### Features:
- **Cluster Metrics:**
  - Total memory available
  - Total VCores
  - Active/pending applications
  
- **Applications:**
  - Running applications list
  - Completed applications history
  - Application logs and metrics
  
- **Nodes:**
  - NodeManager status
  - Resource usage per node
  
- **Scheduler:**
  - Queue configuration
  - Resource allocation
  - Capacity planning

### Key Pages:
- Applications: http://localhost:8088/cluster/apps
- Nodes: http://localhost:8088/cluster/nodes
- Scheduler: http://localhost:8088/cluster/scheduler

**Note:** For this project, YARN may show 0 active NodeManagers since we're using Spark Standalone mode instead of YARN for job scheduling.

---

## 3. Spark Master UI

**URL:** http://localhost:8080

### Features:
- **Cluster Summary:**
  - Workers alive/dead
  - Total cores available
  - Total memory
  - Running/completed applications
  
- **Workers Tab:**
  - List of Spark workers
  - Cores and memory per worker
  - Running executors
  
- **Running Applications:**
  - Active Spark jobs
  - Job progress
  - Resource usage
  
- **Completed Applications:**
  - Historical job data
  - Execution time
  - Success/failure status

### Expected Values (Healthy Cluster):
```
Workers: 2 (spark-worker1, spark-worker2)
Cores: 4 total (2 per worker)
Memory: 2 GB total (1 GB per worker)
Status: ALIVE
```

### Application History:
After running `make test-spark`, you should see completed applications with:
- Name: Spark Pi
- Cores Used: 4
- Duration: ~7 seconds
- Status: FINISHED

---

## 4. Spark Worker UIs

**Worker 1:** http://localhost:8081  
**Worker 2:** http://localhost:8082

### Features:
- **Worker Summary:**
  - Worker ID
  - Master URL
  - Cores/memory capacity
  - Cores/memory in use
  
- **Running Executors:**
  - Active executor processes
  - Logs for each executor
  
- **Finished Executors:**
  - Historical executor data

### Logs Access:
- Worker logs: Click "logs" link on worker page
- Executor logs: Click executor ID → stdout/stderr

---

## 5. DataNode UIs

**DataNode 1:** http://localhost:9864  
**DataNode 2:** http://localhost:9865  
**DataNode 3:** http://localhost:9866  
**DataNode 4:** http://localhost:9867

### Features:
- **DataNode Information:**
  - Storage capacity
  - Blocks stored
  - Last heartbeat to NameNode
  
- **Storage Volumes:**
  - Mount points
  - Capacity per volume
  
- **Logs:**
  - DataNode logs viewer

**Note:** These UIs are less frequently used. Most monitoring is done via NameNode UI.

---

## 6. Spark Application UI (Dynamic)

**URL:** http://localhost:4040 (available only when Spark job is running)

### Features:
- **Jobs:**
  - Active/completed jobs
  - Stages per job
  - Tasks per stage
  
- **Stages:**
  - Stage DAG visualization
  - Task metrics (duration, GC time)
  
- **Storage:**
  - Cached RDDs/DataFrames
  
- **Environment:**
  - Spark properties
  - System properties
  - Classpath
  
- **Executors:**
  - Executor list with resource usage
  - Task summary per executor
  
- **SQL:**
  - SQL query execution plans (if using Spark SQL)

**Usage:**
While a Spark job is running (e.g., `make test-spark` in another terminal), you can access this UI to monitor real-time progress.

---

## Quick Health Check

Run these commands to verify all UIs are accessible:

```bash
# Check all web endpoints
curl -s -o /dev/null -w "NameNode UI: %{http_code}\n" http://localhost:9870
curl -s -o /dev/null -w "ResourceManager UI: %{http_code}\n" http://localhost:8088
curl -s -o /dev/null -w "Spark Master UI: %{http_code}\n" http://localhost:8080
curl -s -o /dev/null -w "Spark Worker 1 UI: %{http_code}\n" http://localhost:8081
curl -s -o /dev/null -w "Spark Worker 2 UI: %{http_code}\n" http://localhost:8082
curl -s -o /dev/null -w "DataNode 1 UI: %{http_code}\n" http://localhost:9864
```

**Expected Output:** All should return `200` or `302` (redirect).

---

## Screenshots Checklist

For project documentation, capture these screenshots:

1. **NameNode Overview:**
   - http://localhost:9870 → Overview tab showing 4 live DataNodes
   
2. **NameNode File Browser:**
   - http://localhost:9870/explorer.html#/ showing `/data/raw/` directory
   
3. **Spark Master:**
   - http://localhost:8080 showing 2 alive workers
   
4. **Spark Completed Application:**
   - http://localhost:8080 → Completed Applications showing "Spark Pi" job
   
5. **Spark Job Details (optional):**
   - While running a job, capture http://localhost:4040/jobs/ showing DAG visualization

---

## Troubleshooting

### UI Not Accessible
1. **Check container status:**
   ```bash
   make status
   ```
   Ensure all services show "healthy" status.

2. **Check port bindings:**
   ```bash
   docker ps --format "table {{.Names}}\t{{.Ports}}"
   ```
   Verify ports 9870, 8088, 8080, 8081, 8082 are mapped.

3. **Check firewall:**
   Ensure your firewall allows connections to localhost ports.

4. **Wait for initialization:**
   Services may take 60-90 seconds to become fully available after `make up`.

### UI Shows Errors
1. **NameNode UI shows 0 DataNodes:**
   - Wait 2-3 minutes for DataNodes to register
   - Check healthcheck: `docker ps` should show "healthy"
   - Review logs: `make logs S=namenode`

2. **Spark UI shows 0 workers:**
   - Check worker containers: `make status`
   - Review worker logs: `make logs S=spark-worker1`

### Browser Cache Issues
If UI shows stale data:
1. Hard refresh: `Ctrl+Shift+R` (Linux/Windows) or `Cmd+Shift+R` (Mac)
2. Clear browser cache for localhost
3. Try incognito/private browsing mode

---

## References

- [NameNode UI Documentation](https://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-hdfs/HdfsUserGuide.html#Web_Interface)
- [Spark Web UI Guide](https://spark.apache.org/docs/latest/web-ui.html)
- [YARN ResourceManager UI](https://hadoop.apache.org/docs/current/hadoop-yarn/hadoop-yarn-site/ResourceManagerRest.html)

---

**Next:** [HDFS Operations Guide](hdfs-operations-guide.md) | [README](../README.md)
