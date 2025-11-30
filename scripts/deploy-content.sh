#!/bin/bash
set -e

echo "================================"
echo "Mossy Life - Content Deploy (Flat Structure)"
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
command -v aws >/dev/null 2>&1 || { echo -e "${RED}Error: AWS CLI is required but not installed.${NC}" >&2; exit 1; }

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

# Get Terraform outputs
cd "$PROJECT_ROOT/terraform"

if [ ! -d ".terraform" ]; then
    echo -e "${RED}Error: Infrastructure not deployed. Run ./scripts/deploy.sh first.${NC}" >&2
    exit 1
fi

API_GATEWAY_URL=$(terraform output -raw api_gateway_track_endpoint 2>/dev/null)
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null)
CLOUDFRONT_DIST=$(terraform output -raw cloudfront_distribution_id 2>/dev/null)
CLOUDFRONT_URL=$(terraform output -raw cloudfront_url 2>/dev/null)

if [ -z "$S3_BUCKET" ]; then
    echo -e "${RED}Error: Could not retrieve S3 bucket name. Infrastructure may not be deployed.${NC}" >&2
    exit 1
fi

echo -e "${YELLOW}Deploying content to: $S3_BUCKET${NC}"
echo ""

# Create temporary directory for processed files
TEMP_DIR=$(mktemp -d)
cp -r "$PROJECT_ROOT/src/frontend/." "$TEMP_DIR/"

# Replace API endpoint placeholder in analytics.js
echo -e "${YELLOW}Processing analytics.js...${NC}"
sed -i.bak "s|API_GATEWAY_URL_PLACEHOLDER|$API_GATEWAY_URL|g" "$TEMP_DIR/shared/js/analytics.js"
rm -f "$TEMP_DIR/shared/js/analytics.js.bak"

echo -e "${YELLOW}Uploading HTML files to S3...${NC}"

# Upload all HTML files from root
for html_file in "$TEMP_DIR"/*.html; do
    if [ -f "$html_file" ]; then
        filename=$(basename "$html_file")
        echo "  Uploading $filename"
        aws s3 cp "$html_file" "s3://$S3_BUCKET/$filename" \
            --profile "$AWS_PROFILE" \
            --content-type "text/html" \
            --cache-control "public, max-age=3600" \
            --metadata-directive REPLACE
    fi
done

# Upload shared CSS
if [ -f "$TEMP_DIR/shared/css/main.css" ]; then
    aws s3 cp "$TEMP_DIR/shared/css/main.css" "s3://$S3_BUCKET/shared/css/main.css" \
        --profile "$AWS_PROFILE" \
        --content-type "text/css" \
        --cache-control "public, max-age=86400" \
        --metadata-directive REPLACE
fi

# Upload shared JS
aws s3 cp "$TEMP_DIR/shared/js/analytics.js" "s3://$S3_BUCKET/shared/js/analytics.js" \
    --profile "$AWS_PROFILE" \
    --content-type "application/javascript" \
    --cache-control "public, max-age=86400" \
    --metadata-directive REPLACE

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

# Create sitemap.xml with flat structure URLs
cat > "$TEMP_DIR/sitemap.xml" << 'SITEMAP_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>CLOUDFRONT_URL_PLACEHOLDER/</loc>
    <lastmod>DATE_PLACEHOLDER</lastmod>
    <changefreq>weekly</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>CLOUDFRONT_URL_PLACEHOLDER/blog-quantum-fiber-review.html</loc>
    <lastmod>DATE_PLACEHOLDER</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.8</priority>
  </url>
  <url>
    <loc>CLOUDFRONT_URL_PLACEHOLDER/recipes.html</loc>
    <lastmod>DATE_PLACEHOLDER</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
  <url>
    <loc>CLOUDFRONT_URL_PLACEHOLDER/recipe-cultured-butter.html</loc>
    <lastmod>DATE_PLACEHOLDER</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
  <url>
    <loc>CLOUDFRONT_URL_PLACEHOLDER/recipe-pie-dough.html</loc>
    <lastmod>DATE_PLACEHOLDER</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
  <url>
    <loc>CLOUDFRONT_URL_PLACEHOLDER/recipe-shio-koji.html</loc>
    <lastmod>DATE_PLACEHOLDER</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.7</priority>
  </url>
  <url>
    <loc>CLOUDFRONT_URL_PLACEHOLDER/about.html</loc>
    <lastmod>DATE_PLACEHOLDER</lastmod>
    <changefreq>monthly</changefreq>
    <priority>0.5</priority>
  </url>
  <url>
    <loc>CLOUDFRONT_URL_PLACEHOLDER/privacy.html</loc>
    <lastmod>DATE_PLACEHOLDER</lastmod>
    <changefreq>yearly</changefreq>
    <priority>0.3</priority>
  </url>
</urlset>
SITEMAP_EOF

# Replace placeholders (macOS compatible)
sed -i.bak "s|CLOUDFRONT_URL_PLACEHOLDER|$CLOUDFRONT_URL|g" "$TEMP_DIR/sitemap.xml"
sed -i.bak "s|DATE_PLACEHOLDER|$(date +%Y-%m-%d)|g" "$TEMP_DIR/sitemap.xml"
rm -f "$TEMP_DIR/sitemap.xml.bak"

aws s3 cp "$TEMP_DIR/sitemap.xml" "s3://$S3_BUCKET/sitemap.xml" \
    --profile "$AWS_PROFILE" \
    --content-type "application/xml" \
    --cache-control "public, max-age=86400"

echo -e "${GREEN}✓ Files uploaded${NC}"
echo ""

echo -e "${YELLOW}Invalidating CloudFront cache...${NC}"
INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --profile "$AWS_PROFILE" \
    --distribution-id "$CLOUDFRONT_DIST" \
    --paths "/*" \
    --query 'Invalidation.Id' \
    --output text)

echo -e "${GREEN}✓ Cache invalidation created: $INVALIDATION_ID${NC}"
echo ""

# Clean up
rm -rf "$TEMP_DIR"

echo "================================"
echo -e "${GREEN}Content Deployment Complete!${NC}"
echo "================================"
echo ""
echo "Your updated site will be available at:"
echo -e "${GREEN}$CLOUDFRONT_URL${NC}"
echo ""
echo "Pages deployed:"
echo "  - Home: $CLOUDFRONT_URL/"
echo "  - Blog: $CLOUDFRONT_URL/blog-quantum-fiber-review.html"
echo "  - Recipes: $CLOUDFRONT_URL/recipes.html"
echo "  - About: $CLOUDFRONT_URL/about.html"
echo "  - Privacy: $CLOUDFRONT_URL/privacy.html"
echo ""
echo -e "${YELLOW}Note: CloudFront cache invalidation may take 1-3 minutes.${NC}"
echo ""
echo "To check invalidation status:"
echo "  aws cloudfront get-invalidation --profile $AWS_PROFILE --distribution-id $CLOUDFRONT_DIST --id $INVALIDATION_ID"
