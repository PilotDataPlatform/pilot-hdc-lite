#!/bin/bash

echo "=== Service Passwords ==="

echo ""
echo "=== Keycloak Admin ==="
echo "Username: user"
echo "Password: $(kubectl get secret keycloak -n keycloak -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d || echo 'Not found')"

echo ""
echo "=== MinIO Root ==="
echo "Username: $(kubectl get secret minio -n minio -o jsonpath='{.data.root-user}' 2>/dev/null | base64 -d || echo 'Not found')"
echo "Password: $(kubectl get secret minio -n minio -o jsonpath='{.data.root-password}' 2>/dev/null | base64 -d || echo 'Not found')"

echo ""
echo "=== PostgreSQL (Keycloak backend) ==="
echo "Username: bn_keycloak"
echo "Password: $(kubectl get secret postgres-postgresql -n keycloak -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo 'Not found')"

echo ""
echo "=== PostgreSQL (Utility namespace) ==="
echo "Username: postgres"
echo "Password: $(kubectl get secret postgres-postgresql -n utility -o jsonpath='{.data.postgres-password}' 2>/dev/null | base64 -d || echo 'Not found')"

echo ""