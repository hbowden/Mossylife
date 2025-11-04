#!/bin/bash
set -e

echo "================================"
echo "Mossy Life - Full Deploy"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# AWS Profile (can be overridden with AWS_PROFILE env var)
AWS_PROFILE="${AWS_PROFILE:-personal}"
export AWS_PROFILE

echo -e "${YELLOW}Using AWS Profile: $AWS_PROFILE${NC}"
echo ""

# Check prerequisites
command -v terraform >/dev/null 2>&1 || { echo -e "${RED}Error: terraform is required but not installed.${NC}" >&2; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "${RED}Error: AWS CLI is required but not installed.${NC}" >&2; exit 1; }
command -v node >/dev/null 2>&1 || { echo -e "${RED}Error: Node.js is required but not installed.${NC}" >&2; exit 1; }

# Verify AWS credentials
echo -e "${YELLOW}Verifying AWS credentials...${NC}"
aws sts get-caller-identity --profile "$AWS_PROFILE" >/dev/null 2>&1 || {
    echo -e "${RED}Error: AWS credentials not valid. Run: aws sso login --profile $AWS_PROFILE${NC}" >&2
    exit 1
}
echo -e "${GREEN}✓ AWS credentials verified${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${YELLOW}Step 1: Building Lambda function...${NC}"
cd "$PROJECT_ROOT/src/backend/analytics-lambda"

# Install dependencies
npm install --production

# Create build directory
mkdir -p "$PROJECT_ROOT/build"

# Create Lambda deployment package
zip -r "$PROJECT_ROOT/build/analytics-lambda.zip" . -x "*.git*" "node_modules/aws-sdk/*"

echo -e "${GREEN}✓ Lambda package created${NC}"
echo ""

echo -e "${YELLOW}Step 2: Deploying infrastructure with Terraform...${NC}"
cd "$PROJECT_ROOT/terraform"

# Initialize Terraform if needed
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..."
    terraform init
fi

# Plan and apply
terraform plan -out=tfplan
terraform apply tfplan

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo ""

# Get outputs
API_GATEWAY_URL=$(terraform output -raw api_gateway_track_endpoint)
S3_BUCKET=$(terraform output -raw s3_bucket_name)
CLOUDFRONT_DIST=$(terraform output -raw cloudfront_distribution_id)
CLOUDFRONT_URL=$(terraform output -raw cloudfront_url)

echo -e "${YELLOW}Step 3: Preparing frontend files...${NC}"

# Create temporary directory for processed files
TEMP_DIR=$(mktemp -d)
cp -r "$PROJECT_ROOT/src/frontend/." "$TEMP_DIR/"

# Replace API endpoint placeholder in analytics.js
if [ -f "$TEMP_DIR/shared/js/analytics.js" ]; then
    sed -i.bak "s|API_GATEWAY_URL_PLACEHOLDER|$API_GATEWAY_URL|g" "$TEMP_DIR/shared/js/analytics.js"
    rm -f "$TEMP_DIR/shared/js/analytics.js.bak"
fi

echo -e "${GREEN}✓ Frontend files prepared${NC}"
echo ""

echo -e "${YELLOW}Step 4: Uploading to S3...${NC}"

# Upload home page
if [ -f "$TEMP_DIR/index.html" ]; then
    aws s3 cp "$TEMP_DIR/index.html" "s3://$S3_BUCKET/index.html" \
        --profile "$AWS_PROFILE" \
        --content-type "text/html" \
        --cache-control "public, max-age=3600" \
        --metadata-directive REPLACE
fi

# Upload blog post
if [ -f "$TEMP_DIR/blog/quantum-fiber-review/index.html" ]; then
    aws s3 cp "$TEMP_DIR/blog/quantum-fiber-review/index.html" "s3://$S3_BUCKET/blog/quantum-fiber-review/index.html" \
        --profile "$AWS_PROFILE" \
        --content-type "text/html" \
        --cache-control "public, max-age=3600" \
        --metadata-directive REPLACE
fi

# Upload shared CSS
if [ -f "$TEMP_DIR/shared/css/main.css" ]; then
    aws s3 cp "$TEMP_DIR/shared/css/main.css" "s3://$S3_BUCKET/shared/css/main.css" \
        --profile "$AWS_PROFILE" \
        --content-type "text/css" \
        --cache-control "public, max-age=86400" \
        --metadata-directive REPLACE
fi

# Upload shared JS
if [ -f "$TEMP_DIR/shared/js/analytics.js" ]; then
    aws s3 cp "$TEMP_DIR/shared/js/analytics.js" "s3://$S3_BUCKET/shared/js/analytics.js" \
        --profile "$AWS_PROFILE" \
        --content-type "application/javascript" \
        --cache-control "public, max-age=86400" \
        --metadata-directive REPLACE
fi

# Upload images if they exist
if [ -d "$TEMP_DIR/images" ] && [ "$(ls -A $TEMP_DIR/images 2>/dev/null)" ]; then
    echo -e "${YELLOW}Uploading images...${NC}"
    aws s3 sync "$TEMP_DIR/images/" "s3://$S3_BUCKET/images/" \
        --profile "$AWS_PROFILE" \
        --cache-control "public, max-age=2592000" \
        --exclude "*.html"
fi

# Upload robots.txt
if [ -f "$TEMP_DIR/robots.txt" ]; then
    sed "s|https://mossylife.com|$CLOUDFRONT_URL|g" "$TEMP_DIR/robots.txt" > "$TEMP_DIR/robots_processed.txt"
    aws s3 cp "$TEMP_DIR/robots_processed.txt" "s3://$S3_BUCKET/robots.txt" \
        --profile "$AWS_PROFILE" \
        --content-type "text/plain" \
        --cache-control "public, max-age=86400"
fi

# Create sitemap.xml with all pages
cat > "$TEMP_DIR/sitemap.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>$CLOUDFRONT_URL/</loc>
    <lastmod>$(date +%Y-%m-%d)</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>$CLOUDFRONT_URL/blog/quantum-fiber-review/</loc>
    <lastmod>$(date +%Y-%m-%d)</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
</urlset>
EOF

aws s3 cp "$TEMP_DIR/sitemap.xml" "s3://$S3_BUCKET/sitemap.xml" \
    --profile "$AWS_PROFILE" \
    --content-type "application/xml" \
    --cache-control "public, max-age=86400"

echo -e "${GREEN}✓ Files uploaded to S3${NC}"
echo ""

echo -e "${YELLOW}Step 5: Invalidating CloudFront cache...${NC}"
aws cloudfront create-invalidation \
    --profile "$AWS_PROFILE" \
    --distribution-id "$CLOUDFRONT_DIST" \
    --paths "/*" \
    > /dev/null

echo -e "${GREEN}✓ CloudFront cache invalidated${NC}"
echo ""

# Clean up
rm -rf "$TEMP_DIR"

echo "================================"
echo -e "${GREEN}Deployment Complete!${NC}"
echo "================================"
echo ""
echo "Your site is available at:"
echo -e "${GREEN}$CLOUDFRONT_URL${NC}"
echo ""
echo "Pages deployed:"
echo "  - Home: $CLOUDFRONT_URL/"
echo "  - Blog: $CLOUDFRONT_URL/blog/quantum-fiber-review/"
echo ""
echo "API Gateway Endpoint:"
echo "$API_GATEWAY_URL"
echo ""
echo "S3 Bucket:"
echo "$S3_BUCKET"
echo ""
echo -e "${YELLOW}Note: CloudFront distribution may take 5-10 minutes to fully propagate.${NC}"
echo ""
echo "To deploy content updates only (faster), use:"
echo "  ./scripts/deploy-content.sh"
