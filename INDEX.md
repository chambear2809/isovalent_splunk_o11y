# Isovalent + Splunk Observability Cloud Lab Guide

## 📚 Documentation Index

This repository contains comprehensive documentation for deploying Isovalent Enterprise Platform (Cilium, Hubble, and Tetragon) on Amazon EKS with Splunk Observability Cloud integration.

## 📖 Available Guides

### 1. [README.md](README.md) - Complete Lab Guide
The main comprehensive guide covering:
- Prerequisites and setup
- Step-by-step installation instructions
- Configuration details
- Verification procedures
- Troubleshooting guide
- Best practices

**Start here** if you're new to this integration.

### 2. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Command Reference
Quick reference containing:
- All commands in sequential order
- Copy-paste ready commands
- Verification commands
- Troubleshooting commands
- Cleanup procedures

**Use this** for quick command lookups during installation.

### 3. [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture Documentation
Deep dive into the architecture including:
- System architecture diagram (ASCII art)
- Component details
- Data flow diagrams
- Security considerations
- Scalability and HA information
- Monitoring and observability details

**Read this** to understand how everything fits together.

## 🎯 Quick Start

### Estimated Time
- **EKS Cluster Creation**: 15-20 minutes
- **Cilium Installation**: 5-10 minutes
- **Complete Setup**: ~30-40 minutes total

### What You'll Build

```
┌──────────────────────────────────────┐
│  Splunk Observability Cloud          │
│  • Metrics Dashboard                 │
│  • Infrastructure Navigator          │
└──────────────┬───────────────────────┘
               │ OTLP/HTTPS
               ▼
┌──────────────────────────────────────┐
│  Splunk OpenTelemetry Collector      │
│  • Prometheus Receivers              │
│  • Metrics Pipeline                  │
└──────────────┬───────────────────────┘
               │ Scrape Metrics
               ▼
┌──────────────────────────────────────┐
│  Amazon EKS Cluster                  │
│  ┌────────────────────────────────┐  │
│  │ Cilium (CNI + Network Policy)  │  │
│  │ • ENI Mode                     │  │
│  │ • eBPF Datapath                │  │
│  │ • Kube-Proxy Replacement       │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ Hubble (Network Observability) │  │
│  │ • Flow Metrics                 │  │
│  │ • L7 Visibility                │  │
│  │ • Timescape                    │  │
│  └────────────────────────────────┘  │
│  ┌────────────────────────────────┐  │
│  │ Tetragon (Runtime Security)    │  │
│  │ • Process Monitoring           │  │
│  │ • System Call Tracing          │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

### Prerequisites Checklist

- [ ] AWS CLI installed and configured
- [ ] kubectl installed
- [ ] eksctl installed
- [ ] Helm 3.x installed
- [ ] Splunk Observability Cloud account
- [ ] Splunk access token
- [ ] AWS permissions for EKS/VPC/EC2

### Installation Path

1. **Preparation** (5 min)
   - Add Helm repositories
   - Create configuration files
   - Set environment variables

2. **Infrastructure** (15-20 min)
   - Create EKS cluster
   - Create node group

3. **Cilium & Observability** (10 min)
   - Install Cilium with ENI mode
   - Enable Hubble
   - Install Tetragon
   - Configure DNS Proxy HA

4. **Splunk Integration** (5 min)
   - Configure OTel Collector
   - Install and verify

## 📊 Key Metrics Collected

### Cilium Metrics (port 9962)
- Network policy enforcement
- Connection tracking
- Endpoint management
- Identity management

### Hubble Metrics (port 9965)
- Flow processing statistics
- Dropped packets analysis
- TCP connection states
- HTTP/L7 performance

### Tetragon Metrics (port 2112)
- Process execution events
- System call monitoring
- File access tracking
- Security policy events

## 🔍 Verification Steps

After installation, verify:

```bash
# 1. Check all components
kubectl get pods -n kube-system | grep -E "(cilium|hubble)"
kubectl get pods -n tetragon
kubectl get pods -n otel-splunk

# 2. Test metrics endpoints
kubectl exec -n kube-system ds/cilium -- curl -s localhost:9962/metrics | head

# 3. Verify OTel collection
kubectl logs -n otel-splunk -l app=splunk-otel-collector --tail=50 | grep cilium

# 4. Check Splunk Observability Cloud
# Navigate to Infrastructure → Kubernetes → Find your cluster
```

## 🛠️ Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Amazon EKS | 1.30 | Kubernetes cluster |
| Cilium | 1.18.8 | CNI + Networking |
| Hubble | Included | Network observability |
| Tetragon | 1.18.1 | Runtime security |
| Splunk OTel Collector chart | 0.147.1 | Metrics collection |
| Prometheus Operator CRDs | 0.68.0 | Metrics monitoring |

## 💰 Cost Considerations

### AWS Costs
- **EKS Control Plane**: ~$73/month
- **Sample EC2 Nodes (2x m5.xlarge from `examples/nodegroup.yaml`)**: ~$280/month
- **Data Transfer**: Variable
- **EBS Volumes**: ~$20/month

### Splunk Costs
- Based on metrics volume and retention
- Free trial available for testing

**Estimated Total**: ~$380-400/month for lab environment

## 🔐 Security Features

✅ **Network Security**
- eBPF-based network policies
- Identity-based segmentation
- L7 traffic filtering

✅ **Runtime Security**
- Process execution monitoring
- System call filtering
- File access control

✅ **TLS Encryption**
- Hubble Relay TLS
- Splunk connection TLS
- Automated certificate management

✅ **RBAC**
- Kubernetes RBAC
- AWS IAM integration (OIDC)
- Service account permissions

## 📈 Scaling Guidelines

### Cluster Scaling
- **Nodes**: Add more nodes via eksctl nodegroup
- **Pods**: Cilium/Tetragon scale automatically (DaemonSet)
- **OTel Collector**: Scales with nodes

### Resource Requirements Per Node
- Cilium: 100m CPU, 256Mi RAM
- Tetragon: 100m CPU, 128Mi RAM
- OTel Collector: 200m CPU, 512Mi RAM

### Maximum Tested
- Nodes: 100+
- Pods: 10,000+
- Flows/sec: 100,000+

## 🚨 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| Nodes not ready | Check Cilium pods are running |
| Metrics missing | Verify OTel Collector configuration |
| High latency | Check ENI limits, increase node size |
| Pod networking issues | Review Cilium status with `cilium status` |

## 📚 Learning Resources

### Beginner
1. Start with README.md walkthrough
2. Follow quick reference commands
3. Verify each step

### Intermediate
1. Review ARCHITECTURE.md
2. Customize configurations
3. Explore Splunk dashboards

### Advanced
1. Performance tuning
2. Custom policies
3. Multi-cluster mesh

## 🤝 Support & Community

### Official Support
- **Isovalent**: support.isovalent.com
- **Splunk**: www.splunk.com/support

### Community Resources
- [Cilium Slack](https://cilium.io/slack)
- [Isovalent Documentation](https://docs.isovalent.com)
- [Splunk Docs](https://docs.splunk.com/Observability)

### Contributing
Found an issue or have improvements?
- Open an issue
- Submit a pull request
- Share your experience

## 🔄 Updates & Changelog

### Version 1.1 (March 2026)
- Updated public docs to match the live cluster and upgrade workflow
- Cilium 1.18.8
- Tetragon 1.18.1
- Splunk OTel Collector chart 0.147.1
- Documented live `Instrumentation` ownership checks and safer Splunk upgrades

### Version 1.0 (November 2025)
- Initial release
- Tested with EKS 1.30
- Cilium 1.18.4
- Tetragon 1.18.0
- Complete Splunk integration

## 📝 License

This lab guide is provided for educational purposes.

## 🙏 Acknowledgments

- Isovalent team for Cilium, Hubble, and Tetragon
- Splunk team for Observability Cloud
- AWS for EKS platform
- OpenTelemetry community

---

**Ready to start?** Head over to [README.md](README.md) for the complete guide!

**Need quick commands?** Check [QUICK_REFERENCE.md](QUICK_REFERENCE.md)!

**Want to understand the architecture?** Read [ARCHITECTURE.md](ARCHITECTURE.md)!
