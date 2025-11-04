# Quantum Fiber Review Site

Fast, SEO-optimized static site with serverless analytics for Quantum Fiber reviews and referral tracking.

## Architecture

- **Frontend**: HTML + Tailwind CSS + Vanilla JS (S3 + CloudFront)
- **Backend**: Node.js Lambda + API Gateway
- **Database**: DynamoDB
- **Infrastructure**: Terraform
- **Region**: us-west-2

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- Node.js >= 18.x
- Domain (optional, can be added later)

## Setup

### 1. Create Terraform State Bucket (One-time setup)

```bash
aws s3 mb s3://qf-review-terraform-state --region us-west-2
aws s3api put-bucket-versioning \
  --bucket qf-review-terraform-state \
  --versioning-configuration Status=Enabled
```

### 2. Initialize Terraform

```bash
cd terraform
terraform init
```

### 3. Deploy Infrastructure

```bash
terraform plan
terraform apply
```

### 4. Deploy Frontend Content

```bash
cd ..
./scripts/deploy-content.sh
```

## Project Structure

```
qf-review/
├── terraform/           # Infrastructure as Code
├── src/
│   ├── frontend/       # Static HTML/CSS/JS
│   └── backend/        # Lambda functions
├── scripts/            # Deployment automation
└── README.md
```

## Deployment

### Full Stack Deployment
```bash
./scripts/deploy.sh
```

### Content-Only Deployment (faster updates)
```bash
./scripts/deploy-content.sh
```

## Configuration

Edit `terraform/variables.tf` to customize:
- Project name
- AWS region
- Domain name (when ready)

## Monitoring

- CloudWatch Logs: Lambda execution logs
- DynamoDB: Analytics data stored in `qf-review-analytics` table

## Cost Estimate

- S3: ~$0.50/month
- CloudFront: ~$1-2/month
- DynamoDB: Free tier
- Lambda: Free tier
- **Total: ~$2-5/month**

## Analytics Tracked

- Page views
- Unique visitors (daily hash)
- Referral link clicks
- Timestamp data

## Performance

- Core Web Vitals optimized
- <100KB initial page load
- CDN edge caching
- Lazy image loading
- Minimal JavaScript
