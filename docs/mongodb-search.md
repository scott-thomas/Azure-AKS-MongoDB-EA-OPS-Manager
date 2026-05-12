# MongoDB Search and Vector Search Guide

This guide explains how to deploy and use MongoDB Search and Vector Search capabilities in your multi-tenant AKS environment.

## Overview

MongoDB Search (powered by the `mongot` process) enables full-text search and vector search capabilities for MongoDB Enterprise Edition 8.2.0 and higher. This deployment uses TLS certificates to ensure secure communication between MongoDB nodes and the search process.

## Prerequisites

- MongoDB Enterprise Edition 8.2.0 or higher
- Sufficient resources for both MongoDB and Search pods
- cert-manager deployed (automatically handled by this Terraform configuration)

## Architecture

When MongoDB Search is enabled for a tenant:

```
tenant-<name> (namespace)
├── MongoDB Replica Set (3+ members)
│   └── TLS certificates for secure communication
├── MongoDB Search Pods
│   └── mongot process with TLS
├── cert-manager Certificates
│   ├── Server certificate (MongoDB)
│   └── Search certificate (mongot)
└── Search Sync User (searchCoordinator role)
```

## Enabling MongoDB Search for a Tenant

### Step 1: Configure Tenant in terraform.tfvars

Add or update your tenant configuration with MongoDB Search enabled:

```hcl
tenants = {
  "data-analytics" = {
    ops_manager_user       = "analytics-user"
    ops_manager_public_key = "analytics-public-api-key"
    ops_manager_org_id     = "analytics-org-id"
    ops_manager_project_id = "analytics-project-id"
    
    # Increase quotas to accommodate MongoDB + Search pods
    cpu_quota    = "30"
    memory_quota = "60Gi"
    storage_quota = "500Gi"
    
    # Enable MongoDB Search
    enable_search         = true
    mongodb_version       = "8.2.0-ent"  # Minimum 8.2.0 required
    mongodb_members       = 3
    search_cpu_limit      = "4"
    search_memory_limit   = "8Gi"
    search_cpu_request    = "3"
    search_memory_request = "5Gi"
  }
}
```

### Step 2: Resource Requirements

**MongoDB Search Resource Requirements:**
- **Minimum**: 2 CPU cores, 3Gi memory
- **Recommended**: 3-4 CPU cores, 5-8Gi memory
- **Tenant Quota**: Must be large enough for MongoDB replica set + Search pods

**Example Resource Calculation:**
- MongoDB (3 replicas): 3 CPUs × 3 = 9 CPUs, 3Gi × 3 = 9Gi memory
- Search (1 instance): 3 CPUs, 5Gi memory
- **Total Minimum**: 12 CPUs, 14Gi memory
- **Recommended Tenant Quota**: 20-30 CPUs, 30-60Gi memory

### Step 3: Deploy

```bash
# Initialize if first time
terraform init

# Plan the changes
terraform plan

# Apply - this will deploy cert-manager, MongoDB, and Search
terraform apply
```

### Step 4: Verify Deployment

```bash
# Check cert-manager is running
kubectl get pods -n cert-manager

# Check tenant namespace
kubectl get all -n tenant-data-analytics

# Check MongoDBSearch resource
kubectl get mongodbsearch -n tenant-data-analytics

# Check certificates
kubectl get certificates -n tenant-data-analytics

# Describe MongoDBSearch to see status
kubectl describe mongodbsearch tenant-data-analytics -n tenant-data-analytics
```

## Using MongoDB Search

### Creating a Search Index

Once MongoDB Search is deployed, you can create search indexes:

```javascript
// Connect to MongoDB
use myDatabase

// Create a search index
db.movies.createSearchIndex(
  "movieSearchIndex",
  {
    mappings: {
      dynamic: true
    }
  }
)

// Check index status
db.movies.getSearchIndexes()
```

### Running Search Queries

**Full-Text Search Example:**

```javascript
db.movies.aggregate([
  {
    $search: {
      index: "movieSearchIndex",
      text: {
        query: "science fiction",
        path: ["title", "plot"]
      }
    }
  },
  {
    $project: {
      title: 1,
      plot: 1,
      score: { $meta: "searchScore" }
    }
  },
  {
    $limit: 10
  }
])
```

**Vector Search Example:**

```javascript
// Create a vector search index
db.movies.createSearchIndex(
  "plotEmbeddingIndex",
  {
    mappings: {
      fields: {
        plot_embedding: {
          type: "knnVector",
          dimensions: 1536,
          similarity: "cosine"
        }
      }
    }
  }
)

// Run vector search
db.movies.aggregate([
  {
    $vectorSearch: {
      index: "plotEmbeddingIndex",
      path: "plot_embedding",
      queryVector: [...], // Your embedding vector
      numCandidates: 100,
      limit: 10
    }
  },
  {
    $project: {
      title: 1,
      plot: 1,
      score: { $meta: "vectorSearchScore" }
    }
  }
])
```

## Monitoring MongoDB Search

### Check Search Pod Status

```bash
# View all pods in tenant namespace
kubectl get pods -n tenant-<name>

# Check search pod logs
kubectl logs -n tenant-<name> <search-pod-name>

# Check resource usage
kubectl top pods -n tenant-<name>
```

### MongoDB Ops Manager

MongoDB Search deployments are visible in Ops Manager:
1. Go to **Deployment** → **Servers**
2. You'll see the search nodes listed alongside MongoDB nodes
3. Monitor search node metrics and logs

## Troubleshooting

### Search Pods Not Starting

**Check certificate status:**
```bash
kubectl get certificates -n tenant-<name>
kubectl describe certificate tenant-<name>-search-tls -n tenant-<name>
```

**Check MongoDBSearch status:**
```bash
kubectl describe mongodbsearch tenant-<name> -n tenant-<name>
```

### TLS Certificate Issues

**Verify CA certificate:**
```bash
kubectl get configmap tenant-<name>-ca-configmap -n tenant-<name> -o yaml
```

**Check cert-manager logs:**
```bash
kubectl logs -n cert-manager -l app=cert-manager
```

### Search Index Not Working

**Verify search node connectivity:**
```bash
# Port forward to MongoDB
kubectl port-forward svc/tenant-<name>-svc 27017:27017 -n tenant-<name>

# Check MongoDB logs for search-related messages
kubectl logs -n tenant-<name> tenant-<name>-0 -c mongodb-enterprise-database
```

**Check search sync user:**
```bash
kubectl get mongodbuser search-sync-source-user -n tenant-<name>
```

### Insufficient Resources

**Check resource quotas:**
```bash
kubectl describe resourcequota -n tenant-<name>
```

**Increase tenant quotas in terraform.tfvars:**
```hcl
cpu_quota    = "40"   # Increase as needed
memory_quota = "80Gi"
```

## Performance Tuning

### Search Pod Resources

Adjust search pod resources based on workload:

```hcl
# For high-throughput search workloads
search_cpu_limit      = "6"
search_memory_limit   = "12Gi"
search_cpu_request    = "4"
search_memory_request = "8Gi"

# For development/testing
search_cpu_limit      = "2"
search_memory_limit   = "4Gi"
search_cpu_request    = "1"
search_memory_request = "2Gi"
```

### MongoDB Version

Ensure you're using a compatible MongoDB version:
- **Minimum**: 8.2.0-ent
- **Recommended**: Latest 8.2.x or 8.3.x enterprise release

## Disabling MongoDB Search

To disable MongoDB Search for a tenant:

1. Update `terraform.tfvars`:
```hcl
tenants = {
  "data-analytics" = {
    # ... other config ...
    enable_search = false  # Disable search
  }
}
```

2. Apply changes:
```bash
terraform apply
```

This will remove:
- MongoDBSearch custom resource
- Search pods
- Search TLS certificates
- Search sync user

**Note**: Your MongoDB replica set will continue operating normally.

## Best Practices

1. **Resource Planning**: Always provision 50-100% more resources than minimum requirements
2. **Index Strategy**: Create specific indexes rather than using dynamic mapping for better performance
3. **Monitoring**: Set up alerts for search pod resource usage and failures
4. **Backup**: Ensure your backup strategy includes search index metadata
5. **Version Compatibility**: Keep MongoDB and Search operator versions in sync

## Additional Resources

- [MongoDB Atlas Search Documentation](https://www.mongodb.com/docs/atlas/atlas-search/)
- [MongoDB Vector Search](https://www.mongodb.com/docs/atlas/atlas-vector-search/vector-search-overview/)
- [MongoDB Kubernetes Operator](https://github.com/mongodb/mongodb-enterprise-kubernetes)
- [cert-manager Documentation](https://cert-manager.io/docs/)
