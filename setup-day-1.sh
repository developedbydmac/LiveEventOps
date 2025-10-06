#!/bin/bash

# LiveEventOps Day 1 Setup Script
# This script handles initial git commits, creates reflection documentation, and pushes to remote

set -e  # Exit on any error

echo "🚀 Starting LiveEventOps Day 1 Setup..."

# 1. Stage all changes for git commit
echo "📁 Staging all changes..."
git add .

# 2. Make initial commit
echo "💾 Creating initial commit..."
git commit -m "chore(day-1): Initial project setup - scaffold repo, use cases, architecture, and pipeline"

# 3. Create reviews folder
echo "📂 Creating reviews folder..."
mkdir -p reviews

# 4. Create reflection markdown file with template
echo "📝 Creating day-1 reflection document..."
cat > reviews/day-1-reflection.md << 'EOF'
# Day 1 Reflection: LiveEventOps Project Setup

## Date
October 6, 2025

## Summary of Work Completed

### Project Scaffolding
- ✅ Created comprehensive folder structure for LiveEventOps project
- ✅ Established directories for: `docs`, `terraform`, `bicep`, `monitoring`, `security`, `ci_cd`, `.github/workflows`, `media`
- ✅ Added initial `.gitignore` with relevant exclusions for Node.js, Python, Terraform, and media files

### Documentation & Use Cases
- ✅ Developed comprehensive README.md covering:
  - Manual event IT setup challenges (APs, cameras, PoE, printers)
  - Business value proposition for Azure automation
  - CI/CD benefits with GitHub Actions
  - Detailed Azure architecture overview
  - Technology stack and project structure

### Architecture Design
- ✅ Defined Azure resource group organization strategy
- ✅ Designed virtual network architecture with hub-spoke topology
- ✅ Planned device virtualization approach (cameras, APs, switches as VMs)
- ✅ Outlined CI/CD pipeline workflows for infrastructure and configuration deployment

### Pipeline & Integration Planning
- ✅ Documented GitHub Actions workflow strategies
- ✅ Planned Azure Monitor integration and incident response automation
- ✅ Designed secret management strategy with Azure Key Vault
- ✅ Created monitoring dashboard integration specifications

## Key Technical Decisions

### Infrastructure as Code (IaC)
- **Decision**: Use both Terraform and Azure Bicep for infrastructure deployment
- **Rationale**: Terraform for multi-cloud flexibility, Bicep for Azure-native optimizations
- **Impact**: Enables comparison of IaC approaches and demonstrates best practices

### Azure Architecture
- **Decision**: Hub-spoke network topology with subnet segmentation
- **Rationale**: Provides security isolation while maintaining centralized management
- **Impact**: Scalable architecture that mirrors real-world event network requirements

### CI/CD Strategy
- **Decision**: GitHub Actions for automation with Azure DevOps integration
- **Rationale**: Native GitHub integration with enterprise-grade Azure DevOps capabilities
- **Impact**: Demonstrates modern DevOps practices for event infrastructure management

### Device Virtualization
- **Decision**: Represent physical devices (cameras, APs) as Azure VMs
- **Rationale**: Enables realistic testing and automation without physical hardware dependency
- **Impact**: Cost-effective development and testing environment for event scenarios

## Challenges Identified

### Complexity Management
- Challenge: Balancing comprehensive documentation with actionable implementation
- Approach: Structured documentation with clear implementation phases

### Real-World Simulation
- Challenge: Accurately simulating physical event constraints in cloud environment
- Approach: VM-based device simulation with realistic network topologies

### Cost Optimization
- Challenge: Keeping Azure costs manageable during development and testing
- Approach: Automated resource lifecycle management and pay-per-use strategies

## Next Steps (Day 2 Planning)

### Immediate Priorities
1. **Terraform Infrastructure**: Create base infrastructure templates for resource groups and networking
2. **GitHub Actions Setup**: Implement initial CI/CD workflows for infrastructure validation
3. **Azure Monitor Configuration**: Set up basic monitoring and alerting for infrastructure health

### Implementation Tasks
- [ ] Create Terraform modules for Azure resource group and VNet setup
- [ ] Develop GitHub Actions workflow for Terraform validation and deployment
- [ ] Configure Azure service principal for automated deployments
- [ ] Set up Azure Key Vault for secrets management
- [ ] Create initial monitoring dashboard templates

### Documentation Updates
- [ ] Add implementation guides to `docs/` folder
- [ ] Create Terraform module documentation
- [ ] Document Azure service principal setup process
- [ ] Add troubleshooting guides for common deployment issues

## Blog Content Ideas

### Technical Blog Posts
1. **"Automating Live Event IT: From Manual Chaos to Cloud Orchestration"**
   - Focus on pain points and solution overview
   - Target audience: Event managers and IT professionals

2. **"Infrastructure as Code for Event Management: Terraform vs. Azure Bicep"**
   - Technical comparison with practical examples
   - Target audience: DevOps engineers and cloud architects

3. **"Building Resilient Event Infrastructure with Azure and GitHub Actions"**
   - CI/CD best practices for event management
   - Target audience: DevOps practitioners

### Business Case Content
1. **"The Hidden Costs of Manual Event IT Setup"**
   - ROI analysis and business value proposition
   - Target audience: Event industry executives

2. **"Scaling Event Operations: How Cloud Automation Changes the Game"**
   - Industry transformation and competitive advantages
   - Target audience: Event technology decision makers

## Lessons Learned

### Documentation First Approach
- **Insight**: Comprehensive documentation upfront clarifies architecture decisions
- **Application**: Continue detailed documentation for each implementation phase

### Azure Service Integration
- **Insight**: Azure's integrated services provide powerful automation capabilities
- **Application**: Leverage native integrations for monitoring, security, and deployment

### Real-World Relevance
- **Insight**: Grounding cloud solutions in actual event IT challenges increases value
- **Application**: Maintain focus on practical event management use cases

## Resources and References

### Azure Documentation
- [Azure Virtual Network Documentation](https://docs.microsoft.com/en-us/azure/virtual-network/)
- [Azure Monitor Overview](https://docs.microsoft.com/en-us/azure/azure-monitor/)
- [Azure Key Vault Documentation](https://docs.microsoft.com/en-us/azure/key-vault/)

### Terraform Resources
- [Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/)

### GitHub Actions
- [GitHub Actions for Azure](https://github.com/Azure/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)

---

*End of Day 1 - Foundation established for LiveEventOps automation platform*
EOF

echo "✅ Reflection document created successfully!"

# 5. Add and commit the reflection file
echo "💾 Committing reflection document..."
git add reviews/day-1-reflection.md
git commit -m "docs(day-1): Added reflection for initial setup"

# 6. Tag the commit as "day-1"
echo "🏷️  Creating day-1 tag..."
git tag -a day-1 -m "Day 1: Initial project setup and architecture documentation"

# 7. Push commits and tags to the default remote branch
echo "📤 Pushing commits and tags to remote..."
git push origin main
git push origin --tags

echo ""
echo "🎉 Day 1 setup completed successfully!"
echo ""
echo "📋 Summary:"
echo "   ✅ Initial commit created with project scaffold"
echo "   ✅ Reflection document added to reviews/day-1-reflection.md"
echo "   ✅ Tagged as 'day-1'"
echo "   ✅ Pushed to remote repository"
echo ""
echo "🚀 Ready for Day 2 implementation!"
