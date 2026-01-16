.PHONY: up down reset logs sh status check-hdfs test-hdfs test-spark help

help: ## Show this help message
	@echo "Gaza YouTube Analytics - Hadoop+Spark Cluster Management"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

up: ## Start the cluster
	docker compose up -d

down: ## Stop the cluster
	docker compose down

reset: ## Full reset: stop, remove volumes, rebuild, start
	@echo "⚠️  This will DELETE all data volumes!"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	docker compose down -v
	docker compose up -d --build
	@echo "✅ Cluster reset complete. Waiting 90s for initialization..."
	@sleep 90
	@make status

logs: ## Show logs for a service (usage: make logs S=namenode)
	@if [ -z "$(S)" ]; then \
		echo "Error: Please specify service name with S=<service>"; \
		echo "Example: make logs S=namenode"; \
		exit 1; \
	fi
	docker compose logs -f $(S)

sh: ## Open shell in a service (usage: make sh S=namenode)
	@if [ -z "$(S)" ]; then \
		echo "Error: Please specify service name with S=<service>"; \
		echo "Example: make sh S=namenode"; \
		exit 1; \
	fi
	docker exec -it $(S) bash

status: ## Show status of all services
	@echo "=== Container Status ==="
	docker compose ps
	@echo ""
	@echo "=== Healthcheck Status ==="
	docker ps --format "table {{.Names}}\t{{.Status}}"

check-hdfs: ## Check HDFS cluster status
	@echo "=== HDFS Cluster Report ==="
	docker exec namenode hdfs dfsadmin -report

test-hdfs: ## Run HDFS functionality test
	@echo "=== Testing HDFS Operations ==="
	@echo "1. Creating test directory..."
	docker exec namenode hdfs dfs -mkdir -p /tmp/test
	@echo "2. Writing test file..."
	docker exec namenode bash -c 'echo "hello from Gaza YouTube Analytics cluster" > /tmp/hello.txt'
	docker exec namenode hdfs dfs -put -f /tmp/hello.txt /tmp/test/
	@echo "3. Reading test file..."
	docker exec namenode hdfs dfs -cat /tmp/test/hello.txt
	@echo "4. Listing HDFS contents..."
	docker exec namenode hdfs dfs -ls -R /tmp/test
	@echo "✅ HDFS test complete!"

test-spark: ## Run Spark PI calculation test
	@echo "=== Testing Spark Cluster ==="
	docker exec spark-master /opt/spark/bin/spark-submit \
		--master spark://spark-master:7077 \
		--class org.apache.spark.examples.SparkPi \
		/opt/spark/examples/jars/spark-examples_2.12-3.4.0.jar 100
	@echo "✅ Spark test complete!"

test-replication: ## Verify HDFS replication factor (should be 2)
	@echo "=== HDFS Replication Test ==="
	@echo "1. Creating test file..."
	docker exec namenode bash -c 'echo "Testing replication with 575 video records" > /tmp/test_replication.txt'
	docker exec namenode hdfs dfs -put -f /tmp/test_replication.txt /tmp/
	@echo "2. Checking block locations and replication..."
	docker exec namenode hdfs fsck /tmp/test_replication.txt -files -blocks -locations
	@echo "3. Cleanup..."
	docker exec namenode hdfs dfs -rm /tmp/test_replication.txt
	@echo "✅ Replication test complete!"

check-capacity: ## Show HDFS storage capacity and usage
	@echo "=== HDFS Capacity Report ==="
	docker exec namenode hdfs dfs -df -h /

list-data: ## List all files in /data directory
	@echo "=== HDFS /data Directory ==="
	docker exec namenode hdfs dfs -ls -h -R /data 2>/dev/null || echo "No /data directory found (create with: hdfs dfs -mkdir -p /data)"
