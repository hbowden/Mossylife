#!/bin/bash
set -e

echo "================================"
echo "Recipe Pages - Access Fix"
echo "================================"
echo ""

AWS_PROFILE="${AWS_PROFILE:-personal}"
BUCKET="qf-review-website"

echo "Step 1: Checking if files exist in S3..."
echo ""

aws s3 ls s3://$BUCKET/recipes/ --recursive --profile $AWS_PROFILE

echo ""
echo "Step 2: Checking object metadata..."
echo ""

echo "recipes/index.html:"
aws s3api head-object --bucket $BUCKET --key recipes/index.html --profile $AWS_PROFILE 2>&1 | grep -E "(ContentType|LastModified|ServerSideEncryption)" || echo "  (metadata check failed)"

echo ""
echo "recipes/cultured-butter/index.html:"
aws s3api head-object --bucket $BUCKET --key recipes/cultured-butter/index.html --profile $AWS_PROFILE 2>&1 | grep -E "(ContentType|LastModified|ServerSideEncryption)" || echo "  (metadata check failed)"

echo ""
echo "Step 3: Testing CloudFront access..."
echo ""

CLOUDFRONT_URL="https://d2diqm88wxxz6b.cloudfront.net"

echo "Testing: $CLOUDFRONT_URL/recipes/"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$CLOUDFRONT_URL/recipes/")
echo "  HTTP Status: $HTTP_CODE"
if [ "$HTTP_CODE" != "200" ]; then
    echo "  ❌ Access denied or not found"
else
    echo "  ✅ Success"
fi

echo ""
echo "Testing: $CLOUDFRONT_URL/recipes/cultured-butter/"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$CLOUDFRONT_URL/recipes/cultured-butter/")
echo "  HTTP Status: $HTTP_CODE"
if [ "$HTTP_CODE" != "200" ]; then
    echo "  ❌ Access denied or not found"
else
    echo "  ✅ Success"
fi

echo ""
echo "================================"
echo "Diagnosis Complete"
echo "================================"
echo ""
echo "If you see 403 errors, the S3 bucket policy should already allow"
echo "CloudFront to access ALL objects (including /recipes/*)"
echo ""
echo "The most common cause is CloudFront caching the 403 error."
echo "Try waiting 5-10 minutes, or create another cache invalidation:"
echo ""
echo "  aws cloudfront create-invalidation \\"
echo "    --profile $AWS_PROFILE \\"
echo "    --distribution-id E20DKM4LVINEXV \\"
echo "    --paths \"/recipes/*\""
echo ""
echo "Alternative: Try accessing via S3 directly (bypassing CloudFront):"
echo "  aws s3 presign s3://$BUCKET/recipes/index.html --profile $AWS_PROFILE"
