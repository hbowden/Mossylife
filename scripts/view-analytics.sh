#!/bin/bash

# Script to view analytics data from DynamoDB

# AWS Profile (can be overridden with AWS_PROFILE env var)
AWS_PROFILE="${AWS_PROFILE:-personal}"
export AWS_PROFILE

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT/terraform"

# Get table name
TABLE_NAME=$(terraform output -raw dynamodb_table_name 2>/dev/null)

if [ -z "$TABLE_NAME" ]; then
    echo "Error: Could not get DynamoDB table name. Is infrastructure deployed?"
    exit 1
fi

echo "================================"
echo "Quantum Fiber Review - Analytics"
echo "Using AWS Profile: $AWS_PROFILE"
echo "================================"
echo ""

# Function to get date stats
get_date_stats() {
    local date=$1
    echo -e "${YELLOW}Stats for $date:${NC}"
    
    aws dynamodb get-item \
        --profile "$AWS_PROFILE" \
        --table-name "$TABLE_NAME" \
        --key "{\"pk\":{\"S\":\"STATS\"},\"sk\":{\"S\":\"DATE#$date\"}}" \
        --output json 2>/dev/null | jq -r '
        if .Item then
            "  Page Views: " + (.Item.pageViews.N // "0"),
            "  Unique Visitors: " + (.Item.uniqueVisitors.N // "0"),
            "  Quantum Fiber Clicks: " + (.Item.quantumFiberClicks.N // "0"),
            "  Amazon Clicks: " + (.Item.amazonClicks.N // "0")
        else
            "  No data for this date"
        end' || echo "  No data for this date"
    echo ""
}

# Get today's date
TODAY=$(date +%Y-%m-%d)

# Get yesterday's date
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    YESTERDAY=$(date -v-1d +%Y-%m-%d)
    WEEK_AGO=$(date -v-7d +%Y-%m-%d)
else
    # Linux
    YESTERDAY=$(date -d "yesterday" +%Y-%m-%d)
    WEEK_AGO=$(date -d "7 days ago" +%Y-%m-%d)
fi

# Show today's stats
get_date_stats "$TODAY"

# Show yesterday's stats
get_date_stats "$YESTERDAY"

# Show last 7 days summary
echo -e "${YELLOW}Last 7 Days Summary:${NC}"
aws dynamodb query \
    --profile "$AWS_PROFILE" \
    --table-name "$TABLE_NAME" \
    --key-condition-expression "pk = :pk AND sk >= :date" \
    --expression-attribute-values "{\":pk\":{\"S\":\"STATS\"},\":date\":{\"S\":\"DATE#$WEEK_AGO\"}}" \
    --output json 2>/dev/null | jq -r '
    if .Items | length > 0 then
        .Items | 
        "  Total Page Views: " + ([.[].pageViews.N | tonumber] | add | tostring),
        "  Total Unique Visitors: " + ([.[].uniqueVisitors.N | tonumber] | add | tostring),
        "  Total Quantum Fiber Clicks: " + ([.[].quantumFiberClicks.N | tonumber] | add | tostring),
        "  Total Amazon Clicks: " + ([.[].amazonClicks.N | tonumber] | add | tostring),
        "  Days with Data: " + (. | length | tostring)
    else
        "  No data for last 7 days"
    end' || echo "  No data available"

echo ""
echo -e "${BLUE}All-Time Stats:${NC}"
aws dynamodb get-item \
    --profile "$AWS_PROFILE" \
    --table-name "$TABLE_NAME" \
    --key "{\"pk\":{\"S\":\"STATS\"},\"sk\":{\"S\":\"ALL_TIME\"}}" \
    --output json 2>/dev/null | jq -r '
    if .Item then
        "  All-Time Quantum Fiber Clicks: " + (.Item.quantumFiberClicks.N // "0"),
        "  All-Time Amazon Clicks: " + (.Item.amazonClicks.N // "0")
    else
        "  No all-time data yet"
    end' || echo "  No all-time data yet"

echo ""
echo -e "${BLUE}Recent Quantum Fiber Clicks:${NC}"
aws dynamodb query \
    --profile "$AWS_PROFILE" \
    --table-name "$TABLE_NAME" \
    --key-condition-expression "pk = :pk" \
    --expression-attribute-values '{":pk":{"S":"QUANTUM_FIBER"}}' \
    --limit 10 \
    --scan-index-forward false \
    --output json 2>/dev/null | jq -r '
    if .Items | length > 0 then
        .Items[] | 
        "  " + .timestamp.S + " - " + (.linkId.S // "unknown") + " - " + (.page.S // "/")
    else
        "  No Quantum Fiber clicks yet"
    end' || echo "  No Quantum Fiber clicks yet"

echo ""
echo -e "${BLUE}Recent Amazon Clicks:${NC}"
aws dynamodb query \
    --profile "$AWS_PROFILE" \
    --table-name "$TABLE_NAME" \
    --key-condition-expression "pk = :pk" \
    --expression-attribute-values '{":pk":{"S":"AMAZON"}}' \
    --limit 10 \
    --scan-index-forward false \
    --output json 2>/dev/null | jq -r '
    if .Items | length > 0 then
        .Items[] | 
        "  " + .timestamp.S + " - " + (.linkText.S // "unknown product") + " - " + (.page.S // "/")
    else
        "  No Amazon clicks yet"
    end' || echo "  No Amazon clicks yet"

echo ""
echo "================================"
echo ""
echo "To view all data in DynamoDB Console:"
echo "https://console.aws.amazon.com/dynamodbv2/home?region=us-west-2#tables"
echo ""
echo "Table name: $TABLE_NAME"
