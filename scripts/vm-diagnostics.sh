#!/bin/bash

# LiveEventOps VM Diagnostics and Troubleshooting Script
# This script gathers logs, runs diagnostics, and performs automated remediation

set -e

# Configuration
RESOURCE_GROUP=""
VM_NAME=""
LOG_ANALYTICS_WORKSPACE=""
SUBSCRIPTION_ID=""
ACTION="diagnose"  # Options: diagnose, restart, logs, health-check
OUTPUT_DIR="./diagnostics-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Help function
show_help() {
    cat << 'EOF'
Usage: ./vm-diagnostics.sh [OPTIONS]

LiveEventOps VM Diagnostics and Troubleshooting Tool

OPTIONS:
    -g, --resource-group    Azure resource group name
    -v, --vm-name          Virtual machine name
    -w, --workspace        Log Analytics workspace name
    -s, --subscription     Azure subscription ID
    -a, --action           Action to perform (diagnose|restart|logs|health-check)
    -o, --output-dir       Output directory for diagnostic files
    -h, --help             Show this help message

ACTIONS:
    diagnose               Full diagnostic analysis (default)
    restart                Restart VM if unhealthy
    logs                   Gather logs only
    health-check           Quick health status check

EXAMPLES:
    # Full diagnostics for management VM
    ./vm-diagnostics.sh -g liveeventops-rg -v management-vm-abc123 -a diagnose

    # Restart unhealthy camera VM
    ./vm-diagnostics.sh -g liveeventops-rg -v camera-1-abc123 -a restart

    # Quick health check for all VMs
    ./vm-diagnostics.sh -g liveeventops-rg -a health-check

ENVIRONMENT VARIABLES:
    AZURE_SUBSCRIPTION_ID  Default subscription ID
    LOG_ANALYTICS_WORKSPACE Default workspace name
    WEBHOOK_URL           GitHub Actions webhook for notifications
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--resource-group)
                RESOURCE_GROUP="$2"
                shift 2
                ;;
            -v|--vm-name)
                VM_NAME="$2"
                shift 2
                ;;
            -w|--workspace)
                LOG_ANALYTICS_WORKSPACE="$2"
                shift 2
                ;;
            -s|--subscription)
                SUBSCRIPTION_ID="$2"
                shift 2
                ;;
            -a|--action)
                ACTION="$2"
                shift 2
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Use environment variables as defaults
    SUBSCRIPTION_ID=${SUBSCRIPTION_ID:-$AZURE_SUBSCRIPTION_ID}
    LOG_ANALYTICS_WORKSPACE=${LOG_ANALYTICS_WORKSPACE:-$LOG_ANALYTICS_WORKSPACE_NAME}
}

# Validate prerequisites
validate_prerequisites() {
    log "Validating prerequisites..."

    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        error "Azure CLI is not installed"
        exit 1
    fi

    # Check Azure login
    if ! az account show &> /dev/null; then
        error "Not logged in to Azure. Run 'az login' first"
        exit 1
    fi

    # Set subscription if provided
    if [[ -n "$SUBSCRIPTION_ID" ]]; then
        log "Setting subscription to $SUBSCRIPTION_ID"
        az account set --subscription "$SUBSCRIPTION_ID"
    fi

    # Validate required parameters based on action
    case $ACTION in
        "diagnose"|"restart"|"logs")
            if [[ -z "$RESOURCE_GROUP" || -z "$VM_NAME" ]]; then
                error "Resource group and VM name are required for action: $ACTION"
                exit 1
            fi
            ;;
        "health-check")
            if [[ -z "$RESOURCE_GROUP" ]]; then
                error "Resource group is required for health-check action"
                exit 1
            fi
            ;;
    esac

    success "Prerequisites validated"
}

# Create output directory
setup_output_directory() {
    mkdir -p "$OUTPUT_DIR"
    log "Output directory: $OUTPUT_DIR"
}

# Get VM basic information
get_vm_info() {
    local vm_name="$1"
    
    log "Gathering VM information for $vm_name..."
    
    # Get VM details
    az vm show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$vm_name" \
        --output json > "$OUTPUT_DIR/${vm_name}_info.json"
    
    # Get VM power state
    local power_state=$(az vm get-instance-view \
        --resource-group "$RESOURCE_GROUP" \
        --name "$vm_name" \
        --query 'instanceView.statuses[?code==`PowerState/running`]' \
        --output tsv)
    
    if [[ -n "$power_state" ]]; then
        success "$vm_name is running"
        return 0
    else
        warning "$vm_name is not running"
        return 1
    fi
}

# Get VM metrics
get_vm_metrics() {
    local vm_name="$1"
    
    log "Gathering VM metrics for $vm_name..."
    
    # Get VM resource ID
    local vm_id=$(az vm show \
        --resource-group "$RESOURCE_GROUP" \
        --name "$vm_name" \
        --query 'id' \
        --output tsv)
    
    # Get CPU metrics (last hour)
    az monitor metrics list \
        --resource "$vm_id" \
        --metric "Percentage CPU" \
        --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)" \
        --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --interval PT5M \
        --output json > "$OUTPUT_DIR/${vm_name}_cpu_metrics.json"
    
    # Get memory metrics if available
    az monitor metrics list \
        --resource "$vm_id" \
        --metric "Available Memory Bytes" \
        --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)" \
        --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --interval PT5M \
        --output json > "$OUTPUT_DIR/${vm_name}_memory_metrics.json" 2>/dev/null || true
    
    # Get network metrics
    az monitor metrics list \
        --resource "$vm_id" \
        --metric "Network In Total" \
        --start-time "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)" \
        --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --interval PT5M \
        --output json > "$OUTPUT_DIR/${vm_name}_network_metrics.json"
}

# Get VM logs from Log Analytics
get_vm_logs() {
    local vm_name="$1"
    
    if [[ -z "$LOG_ANALYTICS_WORKSPACE" ]]; then
        warning "Log Analytics workspace not specified, skipping log retrieval"
        return
    fi
    
    log "Gathering logs for $vm_name from Log Analytics..."
    
    # Get system logs (last hour)
    local query="Syslog | where Computer == \"$vm_name\" | where TimeGenerated > ago(1h) | order by TimeGenerated desc"
    
    az monitor log-analytics query \
        --workspace "$LOG_ANALYTICS_WORKSPACE" \
        --analytics-query "$query" \
        --output json > "$OUTPUT_DIR/${vm_name}_syslog.json" 2>/dev/null || {
        warning "Could not retrieve syslog data for $vm_name"
    }
    
    # Get performance counters
    local perf_query="Perf | where Computer == \"$vm_name\" | where TimeGenerated > ago(1h) | order by TimeGenerated desc"
    
    az monitor log-analytics query \
        --workspace "$LOG_ANALYTICS_WORKSPACE" \
        --analytics-query "$perf_query" \
        --output json > "$OUTPUT_DIR/${vm_name}_performance.json" 2>/dev/null || {
        warning "Could not retrieve performance data for $vm_name"
    }
    
    # Get heartbeat data
    local heartbeat_query="Heartbeat | where Computer == \"$vm_name\" | where TimeGenerated > ago(1h) | order by TimeGenerated desc"
    
    az monitor log-analytics query \
        --workspace "$LOG_ANALYTICS_WORKSPACE" \
        --analytics-query "$heartbeat_query" \
        --output json > "$OUTPUT_DIR/${vm_name}_heartbeat.json" 2>/dev/null || {
        warning "Could not retrieve heartbeat data for $vm_name"
    }
}

# Analyze VM health
analyze_vm_health() {
    local vm_name="$1"
    local health_score=100
    local issues=()
    
    log "Analyzing health for $vm_name..."
    
    # Check if VM is running
    if ! get_vm_info "$vm_name" > /dev/null 2>&1; then
        health_score=$((health_score - 50))
        issues+=("VM is not running")
    fi
    
    # Analyze CPU metrics if available
    if [[ -f "$OUTPUT_DIR/${vm_name}_cpu_metrics.json" ]]; then
        local avg_cpu=$(jq -r '.value[0].timeseries[0].data[] | select(.average != null) | .average' \
            "$OUTPUT_DIR/${vm_name}_cpu_metrics.json" 2>/dev/null | \
            awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
        
        if (( $(echo "$avg_cpu > 80" | bc -l) )); then
            health_score=$((health_score - 20))
            issues+=("High CPU usage: ${avg_cpu}%")
        fi
    fi
    
    # Analyze memory metrics if available
    if [[ -f "$OUTPUT_DIR/${vm_name}_memory_metrics.json" ]]; then
        local avg_memory=$(jq -r '.value[0].timeseries[0].data[] | select(.average != null) | .average' \
            "$OUTPUT_DIR/${vm_name}_memory_metrics.json" 2>/dev/null | \
            awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')
        
        # Convert to MB and check if less than 100MB
        if (( $(echo "$avg_memory < 104857600" | bc -l) )); then
            health_score=$((health_score - 25))
            issues+=("Low available memory: $(echo "scale=0; $avg_memory/1024/1024" | bc)MB")
        fi
    fi
    
    # Check heartbeat data
    if [[ -f "$OUTPUT_DIR/${vm_name}_heartbeat.json" ]]; then
        local heartbeat_count=$(jq -r '.tables[0].rows | length' \
            "$OUTPUT_DIR/${vm_name}_heartbeat.json" 2>/dev/null || echo "0")
        
        if (( heartbeat_count < 5 )); then
            health_score=$((health_score - 30))
            issues+=("Insufficient heartbeat data: $heartbeat_count records")
        fi
    fi
    
    # Save health analysis
    cat > "$OUTPUT_DIR/${vm_name}_health_analysis.json" << EOF
{
    "vm_name": "$vm_name",
    "health_score": $health_score,
    "status": "$([ $health_score -gt 70 ] && echo "healthy" || [ $health_score -gt 40 ] && echo "degraded" || echo "unhealthy")",
    "issues": $(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .),
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    # Output results
    if [[ $health_score -gt 70 ]]; then
        success "$vm_name is healthy (score: $health_score/100)"
    elif [[ $health_score -gt 40 ]]; then
        warning "$vm_name is degraded (score: $health_score/100)"
        log "Issues found:"
        printf '  • %s\n' "${issues[@]}"
    else
        error "$vm_name is unhealthy (score: $health_score/100)"
        log "Critical issues found:"
        printf '  • %s\n' "${issues[@]}"
    fi
    
    return $((100 - health_score))
}

# Restart VM if unhealthy
restart_vm() {
    local vm_name="$1"
    
    log "Checking if $vm_name needs restart..."
    
    # Analyze health first
    if analyze_vm_health "$vm_name"; then
        log "$vm_name is healthy, restart not needed"
        return 0
    fi
    
    warning "$vm_name appears unhealthy, initiating restart..."
    
    # Create restart log
    echo "VM restart initiated at $(date)" > "$OUTPUT_DIR/${vm_name}_restart.log"
    echo "Reason: Health check failed" >> "$OUTPUT_DIR/${vm_name}_restart.log"
    
    # Stop VM
    log "Stopping $vm_name..."
    az vm stop \
        --resource-group "$RESOURCE_GROUP" \
        --name "$vm_name" \
        --no-wait
    
    # Wait for VM to stop
    log "Waiting for $vm_name to stop..."
    az vm wait \
        --resource-group "$RESOURCE_GROUP" \
        --name "$vm_name" \
        --custom "instanceView.statuses[?code=='PowerState/stopped']"
    
    # Start VM
    log "Starting $vm_name..."
    az vm start \
        --resource-group "$RESOURCE_GROUP" \
        --name "$vm_name" \
        --no-wait
    
    # Wait for VM to start
    log "Waiting for $vm_name to start..."
    az vm wait \
        --resource-group "$RESOURCE_GROUP" \
        --name "$vm_name" \
        --custom "instanceView.statuses[?code=='PowerState/running']"
    
    success "$vm_name has been restarted"
    echo "VM restart completed at $(date)" >> "$OUTPUT_DIR/${vm_name}_restart.log"
    
    # Send notification if webhook URL is available
    send_notification "VM Restart" "$vm_name has been automatically restarted due to health issues"
}

# Health check all VMs in resource group
health_check_all() {
    log "Performing health check for all VMs in $RESOURCE_GROUP..."
    
    # Get all VMs in resource group
    local vms=$(az vm list \
        --resource-group "$RESOURCE_GROUP" \
        --query '[].name' \
        --output tsv)
    
    if [[ -z "$vms" ]]; then
        warning "No VMs found in resource group $RESOURCE_GROUP"
        return
    fi
    
    local unhealthy_vms=()
    
    # Check each VM
    while IFS= read -r vm; do
        if [[ -n "$vm" ]]; then
            log "Checking $vm..."
            get_vm_info "$vm"
            get_vm_metrics "$vm"
            get_vm_logs "$vm"
            
            if ! analyze_vm_health "$vm"; then
                unhealthy_vms+=("$vm")
            fi
        fi
    done <<< "$vms"
    
    # Summary
    local total_vms=$(echo "$vms" | wc -l)
    local healthy_vms=$((total_vms - ${#unhealthy_vms[@]}))
    
    cat > "$OUTPUT_DIR/health_check_summary.json" << EOF
{
    "resource_group": "$RESOURCE_GROUP",
    "total_vms": $total_vms,
    "healthy_vms": $healthy_vms,
    "unhealthy_vms": ${#unhealthy_vms[@]},
    "unhealthy_vm_list": $(printf '%s\n' "${unhealthy_vms[@]}" | jq -R . | jq -s .),
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log "Health check summary:"
    log "  Total VMs: $total_vms"
    success "  Healthy VMs: $healthy_vms"
    if [[ ${#unhealthy_vms[@]} -gt 0 ]]; then
        error "  Unhealthy VMs: ${#unhealthy_vms[@]}"
        log "  Unhealthy VM list:"
        printf '    • %s\n' "${unhealthy_vms[@]}"
    fi
}

# Send notification to webhook
send_notification() {
    local title="$1"
    local message="$2"
    
    if [[ -z "$WEBHOOK_URL" ]]; then
        return
    fi
    
    log "Sending notification: $title"
    
    local payload=$(cat << EOF
{
    "title": "$title",
    "message": "$message",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "resource_group": "$RESOURCE_GROUP",
    "vm_name": "$VM_NAME"
}
EOF
)
    
    curl -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$WEBHOOK_URL" &> /dev/null || {
        warning "Failed to send notification"
    }
}

# Generate diagnostic report
generate_report() {
    log "Generating diagnostic report..."
    
    local report_file="$OUTPUT_DIR/diagnostic_report.md"
    
    cat > "$report_file" << EOF
# LiveEventOps VM Diagnostic Report

**Generated:** $(date)
**Resource Group:** $RESOURCE_GROUP
**Action:** $ACTION

## Summary

EOF
    
    if [[ "$ACTION" == "health-check" ]]; then
        if [[ -f "$OUTPUT_DIR/health_check_summary.json" ]]; then
            local summary=$(cat "$OUTPUT_DIR/health_check_summary.json")
            local total=$(echo "$summary" | jq -r '.total_vms')
            local healthy=$(echo "$summary" | jq -r '.healthy_vms')
            local unhealthy=$(echo "$summary" | jq -r '.unhealthy_vms')
            
            cat >> "$report_file" << EOF
- **Total VMs:** $total
- **Healthy VMs:** $healthy
- **Unhealthy VMs:** $unhealthy

EOF
        fi
    elif [[ -n "$VM_NAME" ]]; then
        if [[ -f "$OUTPUT_DIR/${VM_NAME}_health_analysis.json" ]]; then
            local analysis=$(cat "$OUTPUT_DIR/${VM_NAME}_health_analysis.json")
            local score=$(echo "$analysis" | jq -r '.health_score')
            local status=$(echo "$analysis" | jq -r '.status')
            
            cat >> "$report_file" << EOF
- **VM Name:** $VM_NAME
- **Health Score:** $score/100
- **Status:** $status

EOF
        fi
    fi
    
    cat >> "$report_file" << EOF
## Files Generated

EOF
    
    for file in "$OUTPUT_DIR"/*; do
        if [[ -f "$file" && "$file" != "$report_file" ]]; then
            echo "- $(basename "$file")" >> "$report_file"
        fi
    done
    
    success "Diagnostic report generated: $report_file"
}

# Main execution
main() {
    echo "🔍 LiveEventOps VM Diagnostics Tool"
    echo "=================================="
    
    parse_args "$@"
    validate_prerequisites
    setup_output_directory
    
    case $ACTION in
        "diagnose")
            log "Performing full diagnostic analysis for $VM_NAME..."
            get_vm_info "$VM_NAME"
            get_vm_metrics "$VM_NAME"
            get_vm_logs "$VM_NAME"
            analyze_vm_health "$VM_NAME"
            ;;
        "restart")
            log "Checking and restarting $VM_NAME if needed..."
            get_vm_info "$VM_NAME"
            get_vm_metrics "$VM_NAME"
            get_vm_logs "$VM_NAME"
            restart_vm "$VM_NAME"
            ;;
        "logs")
            log "Gathering logs for $VM_NAME..."
            get_vm_logs "$VM_NAME"
            ;;
        "health-check")
            health_check_all
            ;;
        *)
            error "Unknown action: $ACTION"
            show_help
            exit 1
            ;;
    esac
    
    generate_report
    
    success "Diagnostics completed. Output saved to: $OUTPUT_DIR"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
