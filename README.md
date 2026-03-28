# Introduction to Azure - II: Live Session Tutorial
## Duration: 2 Hours 30 Minutes

---

## Session Outline

| Part | Topic | Duration |
|------|-------|----------|
| Part I | Introduction & Overview | 10 mins |
| Part II | Case Study 1 – ARM Templates & Bicep | 50 mins |
| Part II | Case Study 2 – NSGs, ASGs & Custom Routing | 50 mins |
| Part III | Summary & Doubt Resolution | 10 mins |
| **Total** | | **120 mins** |

---

## Prerequisites

Before the session, ensure you have:

1. **Azure Subscription** (Free tier works)
2. **Azure CLI** installed — [Install Guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
3. **VS Code** with Bicep extension installed
4. **Azure Cloud Shell** (fallback — works in browser)

### Quick Verification
```bash
az --version          # Should show 2.x or higher
az login              # Log into your Azure account
az account show       # Confirm subscription is active
```

---

## Repository Structure

```
azure-5/
├── README.md                        ← You are here
├── slides/
│   └── session-slides.md            ← Instructor slides
├── case-study-1/                    ← ARM Templates & Bicep
│   ├── README.md
│   ├── arm/
│   │   ├── main.json                ← Main ARM template
│   │   ├── params.dev.json          ← Dev parameters
│   │   ├── params.staging.json      ← Staging parameters
│   │   └── params.prod.json         ← Prod parameters
│   ├── bicep/
│   │   ├── main.bicep               ← Bicep equivalent
│   │   └── main.bicepparam          ← Bicep parameters
│   └── scripts/
│       ├── deploy-arm.sh            ← ARM deploy script
│       └── deploy-bicep.sh          ← Bicep deploy script
└── case-study-2/                    ← NSGs, ASGs, UDRs
    ├── README.md
    ├── arm/
    │   └── network-security.json    ← 3-tier network ARM template
    └── scripts/
        ├── deploy.sh                ← Deploy script
        └── validate.sh              ← Security validation script
```

---

## Learning Outcomes

By the end of this session, learners will be able to:

- Create modular, parameterized ARM templates for multi-region deployments
- Convert ARM templates to Azure Bicep for cleaner syntax
- Deploy and manage infrastructure via Azure CLI
- Design 3-tier network architectures with NSGs and ASGs
- Configure User Defined Routes (UDRs) for traffic control
- Validate network security configurations programmatically
