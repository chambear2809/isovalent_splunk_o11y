# Splunk Observability Cloud and Isovalent: Revolutionizing Kubernetes Network Monitoring with eBPF

In today's cloud-native landscape, understanding and securing network traffic within Kubernetes clusters has become increasingly complex and critical. Traditional monitoring approaches often fall short when dealing with the dynamic, ephemeral nature of containerized workloads. Splunk Observability Cloud, integrated with Isovalent's eBPF-powered platform, addresses these challenges by leveraging cutting-edge eBPF technology to provide deep, real-time insights into Kubernetes network traffic, including application dependencies and performance bottlenecks, all within the familiar Kubernetes context.

This comprehensive approach enables organizations to not only monitor their applications but also understand the complete network picture - from application-level communications to critical infrastructure dependencies like DNS resolution, time synchronization, and more.

## Understanding eBPF: The Technology Behind Modern Observability

Before diving into how Cisco uses eBPF, it's important to understand what makes this technology so revolutionary. eBPF, which stands for Extended Berkeley Packet Filter, is a technology that allows programs to run in the Linux kernel without requiring kernel modules or changing kernel source code. Think of it as a safe, sandboxed environment where custom monitoring code can execute at the heart of the operating system.

### Why eBPF Changes Everything

Traditional network monitoring typically requires installing agents in user space that must request information from the kernel, process it, and then report it. This approach introduces latency, consumes significant resources, and can miss critical events that happen between polling intervals. eBPF fundamentally changes this model by operating directly within the kernel itself.

When network packets flow through your system, eBPF programs can observe and analyze them in real-time at the kernel level - the exact point where the operating system handles network traffic. This provides several transformative advantages:

**Zero-Copy Efficiency**: Because eBPF programs run in the kernel, they can examine network data without copying it to user space. This dramatically reduces CPU usage and memory overhead, making eBPF-based monitoring incredibly efficient even in high-traffic environments.

**True Real-Time Visibility**: eBPF programs execute synchronously with kernel events. When a network packet arrives, when a connection is established, or when data is transmitted, eBPF sees it immediately - not seconds or milliseconds later during the next polling cycle.

**Comprehensive Context**: Operating at the kernel level means eBPF has access to complete context about network events - process IDs, container IDs, namespaces, security contexts, and more. This rich contextual information is crucial for understanding what's happening in complex Kubernetes environments.

**Safety and Security**: Despite running in the kernel, eBPF programs are verified before execution to ensure they cannot crash the system or introduce security vulnerabilities. This makes eBPF both powerful and safe.

### Why Splunk and Isovalent Chose eBPF for Network Monitoring

Splunk Observability Cloud, powered by Isovalent's enterprise Cilium platform, leverages eBPF for network monitoring in Kubernetes clusters because it provides unparalleled visibility and control over system behavior. Isovalent, founded by the creators of Cilium and eBPF, brings deep expertise in kernel-level networking and observability. In containerized environments where workloads are constantly being created, destroyed, and moved across nodes, traditional monitoring approaches struggle to keep up. eBPF's kernel-level operation ensures that no network activity goes unnoticed, regardless of how dynamic the environment becomes.

**The key advantage for Splunk and Isovalent customers**: You don't need to understand or write any eBPF code. Isovalent's engineering team—the original creators of eBPF technology—has developed, tested, and optimized the eBPF programs that power network monitoring. Splunk Observability Cloud seamlessly ingests and visualizes this data. As a user, you simply deploy the solution and benefit from the insights it provides. The complexity of eBPF programming is completely abstracted away, ensuring the overall health and security of your containerized applications.

## Key Advantages of eBPF-Based Network Monitoring

### 1. Lightweight and Efficient Operation

In production Kubernetes environments, resource efficiency is paramount. Every monitoring tool you deploy consumes CPU, memory, and network bandwidth that could otherwise serve your applications. eBPF-based monitoring is revolutionary in its efficiency.

Traditional monitoring agents running in user space must constantly poll the kernel for information, copy data between kernel and user space, and process that data before reporting it. Each of these steps consumes resources. eBPF eliminates most of this overhead by operating directly in the kernel where network events occur.

In practice, this means eBPF-based network monitoring typically consumes less than 1-2% of CPU resources even in high-traffic environments, compared to 5-10% or more for traditional agents. For memory, the difference is even more dramatic - eBPF programs are measured in kilobytes, while traditional agents often require hundreds of megabytes.

This efficiency is particularly important in dynamic Kubernetes workloads where resource contention can directly impact application performance. With eBPF, you gain comprehensive visibility without sacrificing the performance your applications need.

### 2. Real-Time Visibility Without Compromise

"Real-time" monitoring is often a marketing term that actually means "near real-time with minimal delay." With eBPF, real-time truly means real-time. When a network connection is established between two pods, eBPF sees it at that exact moment. When data flows across the network, eBPF observes it as it happens.

This immediate visibility enables several critical capabilities:

**Instant Anomaly Detection**: Security threats don't wait for the next polling interval. When a compromised pod attempts to establish a connection to an external command-and-control server, eBPF detects it immediately, enabling rapid response before data exfiltration occurs.

**Accurate Performance Analysis**: Understanding application performance requires precise timing information. eBPF can measure network latency at the nanosecond level, providing accurate insights into where bottlenecks occur - is it the network, the application code, or external dependencies?

**Complete Traffic Accounting**: In multi-tenant environments where accurate resource accounting matters, eBPF ensures every byte of network traffic is accounted for, with no sampling gaps or missed connections.

The seamless integration at the kernel level means this visibility comes without the performance penalties typically associated with comprehensive monitoring. Your applications run at full speed while eBPF silently observes everything happening in the network stack.

### 3. Programmability and Customization

While Cisco provides pre-built eBPF programs that cover the vast majority of monitoring needs, the underlying technology is inherently programmable. This means the monitoring capabilities can be precisely tailored to capture specific network traffic details relevant to your unique environment.

For example, if your organization has specific compliance requirements about tracking certain types of network connections, or if you need detailed insights into how a particular application communicates, eBPF programs can be customized to provide exactly that information.

The granularity and flexibility of eBPF are invaluable for:

**Deep Troubleshooting**: When intermittent network issues occur, eBPF can capture detailed information about specific types of traffic, helping pinpoint the root cause that traditional tools might miss.

**Security Analysis**: Security teams can define specific network patterns or behaviors to monitor, such as connections to unusual ports, large data transfers, or communication with unexpected endpoints.

**Compliance Monitoring**: For organizations with regulatory requirements around network monitoring and data flows, eBPF can provide the detailed audit trail necessary for compliance verification.

## Kubernetes-Specific Implementation: Built for Cloud-Native

The Splunk Observability Cloud and Isovalent integration provides eBPF-based network monitoring specifically designed for Kubernetes environments, taking into account the unique challenges and characteristics of orchestrated containerized workloads. Isovalent's platform is built on Cilium, the Cloud Native Computing Foundation (CNCF) graduated project that pioneered the use of eBPF for container networking and security.

### DaemonSet Deployment Model

In Kubernetes, a DaemonSet ensures that a copy of a pod runs on each node in the cluster. Cisco leverages this pattern to deploy eBPF-based monitoring agents. Here's why this approach is ideal:

**Node-Level Visibility**: Since eBPF operates at the kernel level, deploying an agent on each node ensures that all network traffic on that node - regardless of which pods or containers are running - is monitored. As pods move between nodes or new nodes are added to the cluster, the monitoring automatically extends to cover them.

**Automatic Scaling**: As your Kubernetes cluster scales up with new nodes, the DaemonSet automatically deploys monitoring agents to those nodes. As nodes are removed, the agents are cleaned up. This ensures monitoring coverage always matches your cluster size without manual intervention.

**Resource Efficiency**: Because eBPF is so efficient, running an agent on every node has minimal impact. The agents are small, consume few resources, and operate independently, ensuring that a problem with one node's monitoring doesn't affect others.

**Consistent Coverage**: Every node runs the same monitoring code, ensuring consistent visibility across your entire infrastructure. There are no gaps where traffic might go unmonitored.

### Strategic Data Hooks

eBPF programs don't just randomly observe network traffic - they attach to specific, strategic points in the kernel where they can efficiently capture the information needed. Isovalent's implementation, refined through years of production use with Cilium, carefully selects these attachment points to provide comprehensive visibility while minimizing overhead.

**Network Interface Hooks**: By attaching to network interfaces, eBPF can observe all traffic entering and leaving containers, providing visibility into external communications, inter-pod traffic, and connections to Kubernetes services.

**System Call Hooks**: Many network operations ultimately result in system calls (like `connect()`, `send()`, `recv()`). By observing these system calls, eBPF can understand network behavior from the application perspective, not just the raw packet level.

**TCP/IP Stack Hooks**: Attaching at various points in the TCP/IP stack allows eBPF to understand connection state, retransmissions, congestion, and other important protocol-level behaviors that impact application performance.

This multi-layered approach provides a complete picture: not just "did this packet get sent?" but "which container initiated this connection, to what service, using what protocol, and how did it perform?"

## Network Monitoring: Critical for Kubernetes Security

Security in Kubernetes is challenging because the attack surface is large and constantly changing. Containers start and stop, pods move between nodes, and network policies must be enforced dynamically. Traditional security tools that rely on fixed IP addresses or static network topologies struggle in this environment. Network monitoring with eBPF provides a solution.

### The Visibility Challenge in Container Security

Consider what happens in a traditional, non-containerized environment when you want to monitor network security. You might deploy network monitoring tools that examine traffic at specific points - firewalls, routers, or dedicated monitoring appliances. These tools know about servers with fixed IP addresses and can maintain state about what's "normal" for each server.

In Kubernetes, this model breaks down:
- Pods receive dynamic IP addresses that change when they're recreated
- Traffic between pods often stays within a node, never crossing a physical network boundary where traditional tools might observe it
- The sheer volume of connections in a microservices architecture makes manual analysis impractical
- Containers can be compromised and used for attacks within seconds

eBPF-based network monitoring solves these problems by providing visibility at the kernel level on every node, where all network traffic must pass regardless of whether it's internal or external, and by understanding Kubernetes context (pod names, namespaces, labels) rather than just IP addresses.

### Understanding Attack Chains

Modern attacks on Kubernetes clusters rarely rely on a single vulnerability. Instead, attackers chain together multiple exploits to achieve their goals. Network monitoring is crucial because it can detect these attacks at various stages, particularly during lateral movement and data exfiltration phases.

Let's walk through a realistic attack scenario to understand why network monitoring is so critical:

#### Stage 1: Initial Access

An attacker discovers and exploits a vulnerability in an application running in your Kubernetes cluster. This could be anything from a web application vulnerability to a misconfigured container with excessive permissions. At this stage, the attacker gains the ability to execute commands within a container.

**What Network Monitoring Sees**: Initially, this might look like normal application behavior. However, eBPF-based monitoring establishes a baseline of normal network behavior. When the compromised container begins exhibiting unusual patterns - like making DNS queries for domains it's never contacted before or scanning internal network ranges - these anomalies are visible.

#### Stage 2: Privilege Escalation and Policy Bypass

Once inside a container, the attacker attempts to escalate privileges. They might exploit a Pod Security Policy bypass vulnerability that allows them to create a new pod with elevated privileges - perhaps one that can access the host filesystem or has excessive network capabilities.

**What Network Monitoring Sees**: When the attacker creates a privileged pod, that pod's network behavior is immediately visible. If it starts scanning the cluster's internal network, attempting to contact the Kubernetes API server with suspicious requests, or establishing connections to other pods it shouldn't communicate with, eBPF captures these activities. The monitoring understands the Kubernetes context, so it can report "privileged pod in namespace X is attempting connections to API server" rather than just "IP address 10.0.1.5 connected to 10.0.1.1:6443."

#### Stage 3: Data Exfiltration

The ultimate goal of many attacks is to steal sensitive data. The attacker uses their privileged access to locate sensitive information - database credentials, API keys, customer data - and needs to extract it from the cluster. This requires establishing a network connection to an external destination under the attacker's control.

**What Network Monitoring Sees**: This is where eBPF-based network monitoring truly shines. When a pod that normally only communicates with internal services suddenly establishes a connection to an external IP address or domain, especially one that's unusual or flagged as suspicious, this activity is immediately visible. Even if the attacker tries to hide the exfiltration by:
- Using encrypted connections (eBPF can still see that the connection was made, even if it can't inspect encrypted payload)
- Transferring data slowly over time (eBPF tracks all connections, not just high-volume ones)
- Using legitimate protocols like HTTPS (eBPF provides context about what's normal for each pod)

The network flow from the malicious workload is readily identifiable, enabling security teams to respond before significant data loss occurs.

### Real-World Vulnerabilities: Why This Matters

These attack scenarios aren't theoretical. Real vulnerabilities in Kubernetes and container runtimes make these attacks possible, and network monitoring is often the best defense for detecting them in progress.

#### Pod Security Policy Bypass Vulnerabilities

Pod Security Policies (PSPs) are designed to prevent users from creating pods with dangerous configurations. However, vulnerabilities in PSP implementation can allow these protections to be bypassed:

**CVE-2023-5528 (Windows Nodes)**: This vulnerability affects Kubernetes clusters using in-tree storage plugins for Windows nodes. An attacker who can create pods could exploit this vulnerability to escalate privileges to the administrator level. Once they have administrator access, they can access sensitive data, modify cluster configuration, or deploy malicious workloads.

With eBPF-based network monitoring, even if the privilege escalation succeeds, the subsequent malicious activity - like accessing the Kubernetes API with elevated privileges, connecting to external command-and-control servers, or exfiltrating data - would be visible through unusual network patterns.

**CVE-2022-28390 (Kubelet Component)**: The kubelet is the primary agent that runs on each Kubernetes node. This vulnerability could allow an attacker with the ability to create pods to bypass Pod Security Policy restrictions and escalate privileges within the cluster. A compromised kubelet can access all pods on that node, read their environment variables (which often contain credentials), and intercept their network traffic.

Network monitoring provides a critical safety net here. Even if the kubelet is compromised, any attempt to use the stolen credentials to access external resources, or to exfiltrate data from the node, creates network traffic that eBPF can observe and flag as suspicious.

#### Container Runtime Vulnerabilities

Container runtimes like containerd and runc are the low-level components that actually run containers. Vulnerabilities here are particularly dangerous because they can allow attackers to break out of container isolation entirely.

**CVE-2024-21626 (Runc Container Breakout)**: This is one of the most severe types of vulnerabilities. Runc is the underlying container runtime used by Docker, containerd, and most Kubernetes installations. This vulnerability allows an attacker to break out of the container's isolated environment and achieve full root access on the host system.

Once an attacker has root access on the host, they essentially control the entire node, including all containers running on it. They can read any data, modify any configuration, or use the node as a launching point for attacks on other nodes.

Network monitoring becomes crucial for detecting this type of compromise because even with root access on a node, the attacker still needs to communicate with the outside world to receive commands or exfiltrate data. eBPF-based monitoring can detect when processes on the host (not just within containers) establish unusual network connections, providing visibility into this post-exploitation activity.

**CVE-2023-25153 (Containerd Memory Exhaustion)**: While this is a denial-of-service vulnerability rather than a data breach vulnerability, it illustrates another important aspect of network monitoring. An attacker exploiting this vulnerability could cause the containerd daemon to consume all available memory, effectively crashing all containers on that node.

Network monitoring can detect the unusual patterns of network traffic that might precede or accompany such an attack - for example, a pod making repeated requests designed to trigger the vulnerability, or unusual traffic patterns as containers begin failing and being restarted.

### The Defense-in-Depth Principle

It's important to understand that network monitoring with eBPF isn't meant to prevent these vulnerabilities from being exploited - that's the job of vulnerability management, patching, and proper security configurations. Instead, network monitoring provides a critical layer of defense that detects when prevention has failed and an attack is in progress.

Think of it this way:
- **Prevention** (patching, security policies, RBAC) is your locked door
- **Detection** (network monitoring with eBPF) is your security camera and alarm system

Even with the best locks, you still need cameras and alarms because no security is perfect. Network monitoring ensures that when an attacker does find a way in, you know about it quickly and can respond before significant damage occurs.

## Practical Applications: Detecting Data Exfiltration in Action

To truly understand the value of eBPF-based network monitoring, let's walk through a practical scenario of how it detects data exfiltration attempts.

### Normal Application Behavior

Imagine you have a web application running in Kubernetes with the following architecture:
- A frontend pod that serves the web interface
- A backend API pod that handles business logic
- A database pod that stores application data
- Supporting infrastructure like DNS resolution and time synchronization

In normal operation, the network traffic looks like this:
- Frontend pods communicate with backend API pods on specific ports
- Backend API pods communicate with the database pod on the database port
- All pods occasionally communicate with the cluster DNS service to resolve names
- All pods occasionally communicate with NTP servers for time synchronization
- External users connect to the frontend through a load balancer

eBPF-based network monitoring observes all of this traffic and builds a profile of what's "normal" for each pod. It understands:
- Which services each pod typically communicates with
- What ports and protocols are used
- The volume and pattern of traffic
- Which external destinations are accessed (if any)

### When Compromise Occurs

Now suppose an attacker exploits a vulnerability in the backend API and gains the ability to execute commands within that container. They want to exfiltrate customer data from the database. Here's what happens from a network perspective:

**Step 1: Reconnaissance**
The attacker needs to understand the environment. They might:
- Query DNS for internal services to map out the infrastructure
- Scan internal IP ranges to find other services
- Make API calls to the Kubernetes API server to discover cluster configuration

**What eBPF Sees**: The backend API pod is suddenly making DNS queries it's never made before, scanning ports it's never scanned, and possibly connecting to the Kubernetes API in unusual ways. These deviations from the established baseline are flagged as anomalous.

**Step 2: Data Access**
The attacker uses their access to the backend API to query the database and retrieve sensitive information. This might actually look like normal application behavior at the network level - the backend is supposed to talk to the database.

**What eBPF Sees**: While the connection itself might appear normal, eBPF can detect unusual patterns. Is the backend making far more database queries than usual? Is it querying tables it doesn't normally access? Is the volume of data being retrieved unusually large? These patterns become visible through network analysis.

**Step 3: Exfiltration**
The attacker needs to send the stolen data somewhere they can access it. They might:
- Establish a connection to an external server they control
- Use a legitimate-looking protocol like HTTPS to hide the traffic
- Transfer data slowly over time to avoid detection by volume-based alerts

**What eBPF Sees**: This is where the value of comprehensive network monitoring becomes crystal clear. The backend API pod, which in normal operation only communicates with internal services (frontend, database, DNS, NTP), is now establishing a connection to an external IP address or domain. Even if:
- The connection uses HTTPS, so the content is encrypted
- The data transfer is slow and low-volume
- The attacker tries to make it look like a legitimate software update or API call

The fact that this pod is communicating with an external destination it's never contacted before is highly suspicious and immediately visible in the Network Monitoring Flow map.

### The Visibility Advantage

What makes eBPF-based network monitoring so effective for detecting this exfiltration is the combination of comprehensive visibility and contextual awareness:

**Comprehensive**: eBPF sees every network connection, regardless of protocol, volume, or duration. There's no sampling, no polling interval that might miss short-lived connections, no blind spots.

**Contextual**: eBPF doesn't just report "IP 10.0.1.5 connected to 203.0.113.50". It reports "backend-api pod in namespace production connected to external host suspicious-domain.com, which is not in its normal communication pattern."

**Real-Time**: The suspicious connection is detected as it happens, not minutes or hours later, giving security teams the opportunity to respond before significant data loss occurs.

**Baseline-Aware**: Because the system understands what's normal for each pod, it can detect subtle anomalies that might not trigger threshold-based alerts but are nonetheless suspicious in context.

## Network Monitoring vs. APM Flow Maps: Complementary Perspectives

One of the most important aspects of Splunk Observability Cloud is understanding how different types of monitoring complement each other. Application Performance Monitoring (APM) and Network Monitoring provide different, but equally valuable, perspectives on your Kubernetes environment. Splunk APM provides distributed tracing and application insights, while Isovalent's eBPF-based monitoring provides the network and infrastructure layer visibility.

### APM Flow Maps: The Application View

APM has been the gold standard for understanding application behavior for years. APM agents instrument your application code to trace requests as they flow through your system. If a user makes a request to your web application, APM can show you:
- How long the request took to process
- Which services were called to fulfill the request
- Where time was spent (database queries, external API calls, computation)
- Whether errors occurred and where

This application-centric view is incredibly valuable for understanding user experience and application performance. APM excels at answering questions like:
- Why is this API endpoint slow?
- Which database queries are taking the most time?
- How many requests are failing and why?
- What's the user experience for transactions flowing through the system?

However, APM has a limitation: it only sees what the application explicitly does. If the application makes a database call, APM sees it. But APM typically doesn't see:
- Infrastructure-level communications that happen outside the application (DNS, NTP, health checks)
- Network-level retransmissions or connection failures that the application might not even be aware of
- Communications from sidecars or other containers in the same pod that aren't instrumented
- System-level network activity that doesn't originate from application code

### Network Monitoring Flow Maps: The Infrastructure View

Network Monitoring with eBPF provides a fundamentally different perspective. Instead of instrumenting application code, it observes all network activity at the kernel level. This means it sees everything:
- Application traffic that APM also sees, but from the network perspective
- Infrastructure communications like DNS resolution, time synchronization, and health checks
- Sidecar container traffic (service meshes, log collectors, monitoring agents)
- Failed connection attempts that the application might retry transparently
- Network-level performance issues like packet loss or connection timeouts

Network Monitoring excels at answering different questions:
- Which external endpoints are my workloads communicating with?
- Is my DNS resolution working correctly?
- Are there network performance issues (latency, packet loss) affecting my applications?
- What infrastructure dependencies does this workload have?
- Are any workloads communicating with unexpected destinations?

### The Power of Combining Both Views

The real magic happens when you combine APM and Network Monitoring. Consider a troubleshooting scenario:

**Scenario**: Users report that the application is intermittently slow, but only sometimes.

**APM View**: APM shows that during slow periods, database queries are taking longer than usual. The queries themselves look normal, but the latency is high.

**Network Monitoring View**: Network monitoring shows that during these periods, there's significant packet loss on the network path between the application pods and the database pod. Additionally, it shows the database pod's node is experiencing high network retransmission rates.

**Combined Insight**: The slow application performance is due to network-level issues, not application or database problems. The database is responding quickly, but packets are being lost and retransmitted, adding latency. Without Isovalent's network monitoring integrated into Splunk Observability Cloud, you might have spent hours optimizing database queries or application code, never discovering the actual network-level problem.

### Understanding Infrastructure Dependencies

Another critical difference is in understanding infrastructure dependencies. Modern applications rely on many infrastructure services that are easy to overlook:

**DNS Resolution**: Every time your application connects to another service by name, DNS resolution must occur. If DNS is slow or failing, your application suffers, but APM might just show slow connection times without explaining why.

Network Monitoring makes this explicit: "This pod is making 500 DNS queries per second to the cluster DNS service. DNS response time has increased from 5ms to 50ms." This immediately points to DNS as the bottleneck.

**Time Synchronization**: Applications often rely on accurate time for logging, distributed tracing correlation, cache expiration, and more. If NTP synchronization is failing, subtle bugs can appear.

Network Monitoring shows: "This pod has not successfully synchronized time with an NTP server in 30 minutes." APM might show mysterious issues with distributed trace correlation, but Network Monitoring shows the root cause.

**Health Checks and Probes**: Kubernetes constantly runs liveness and readiness probes against your pods. These are network connections that APM typically doesn't instrument because they're infrastructure, not application traffic.

Network Monitoring shows these health checks explicitly, helping you understand if pods are being restarted due to failed probes, and whether those failures are due to network issues or actual application problems.

### Security Visibility: Network Monitoring's Unique Contribution

From a security perspective, Network Monitoring provides visibility that APM simply cannot:

**Unauthorized Communications**: If a pod is compromised and attempts to communicate with an external command-and-control server, APM won't see this unless the malicious code happens to use the same instrumented libraries as your application (unlikely). Network Monitoring sees every network connection at the kernel level, regardless of how it's made.

**Lateral Movement**: If an attacker compromises one pod and uses it to scan the internal network looking for other vulnerable services, this network scanning is invisible to APM (it's not application traffic) but clearly visible to Network Monitoring.

**Data Exfiltration**: When an attacker exfiltrates data, they might use network protocols or connection methods that bypass application-level instrumentation. Network Monitoring catches this because it operates below the application layer, at the kernel where all network traffic must pass.

### The Complete Picture: Use Both

The key takeaway is that APM and Network Monitoring are not competing solutions - they're complementary tools that together provide complete visibility:

- **APM** tells you how your application is behaving from a functional and performance perspective
- **Network Monitoring** tells you how your application is behaving from a network and infrastructure perspective

For comprehensive observability and security in Kubernetes environments, you need both. APM helps you optimize application performance and user experience. Network Monitoring helps you ensure the underlying infrastructure is healthy, secure, and operating as expected.

## Implementing Splunk Observability Cloud with Isovalent: What to Expect

When you deploy Splunk Observability Cloud with Isovalent's eBPF-powered network monitoring in your Kubernetes cluster, here's what the implementation looks like and what you should expect:

### The Deployment Process

The deployment leverages Kubernetes-native tools and patterns, making it familiar to anyone who operates Kubernetes clusters:

**Helm-Based Installation**: Both Splunk OpenTelemetry Collector and Isovalent Enterprise for Cilium are deployed using Helm, the standard package manager for Kubernetes. This means the installation is declarative, repeatable, and easy to manage through CI/CD pipelines.

**Operator Pattern**: The solution uses the Kubernetes Operator pattern, which means it includes custom controllers that manage the lifecycle of monitoring components. As your cluster changes - nodes are added, workloads are scaled, configuration is updated - the operators automatically adjust the monitoring infrastructure to match.

**Certificate Management**: Secure communication between components and your cluster requires TLS certificates. The solution integrates with cert-manager, a popular Kubernetes certificate management tool, to automatically provision and rotate certificates. This eliminates manual certificate management and ensures secure communication.

### What Gets Deployed

When you install Splunk Observability Cloud with Isovalent, several components are deployed to your cluster:

**Splunk OpenTelemetry Collector**: These components receive telemetry data from Cilium/Hubble eBPF agents and other collectors, process it, and forward it to Splunk Observability Cloud. They're deployed as DaemonSets (one per node) for network telemetry and use the native OpenTelemetry standard.

**Isovalent Enterprise for Cilium**: The core eBPF networking and observability platform that provides deep network visibility through Hubble. Cilium agents run as DaemonSets on each node, embedding eBPF programs directly in the kernel.

**Hubble Relay and UI**: Hubble is Cilium's observability layer that provides network flow visibility. The relay aggregates flow data from all nodes, making it available for export to Splunk.

**Infrastructure Collectors**: These monitor node-level and container-level metrics - CPU, memory, disk, etc. While not directly related to network monitoring, they provide important context for understanding network behavior.

**Cluster Collectors**: These monitor Kubernetes-level metrics and events - pod lifecycle, deployments, services, etc. This Kubernetes context is what allows Network Monitoring to report "backend-api pod in namespace production" rather than just "process 1234 on IP 10.0.1.5".

### Resource Requirements

One of the advantages of eBPF-based monitoring is its efficiency. Typically, you can expect:

**CPU Usage**: Less than 1-2% per node for the network monitoring components, even under high network load. This is dramatically lower than traditional network monitoring agents.

**Memory Usage**: The eBPF programs themselves are tiny (measured in kilobytes). The collectors that aggregate and forward data typically use 50-100MB per node, which is modest in modern Kubernetes environments.

**Network Usage**: The monitoring data itself generates network traffic, but it's compressed and efficiently transmitted. Typically, monitoring traffic is less than 1-2% of your application traffic volume.

### Time to Value

One of the remarkable aspects of eBPF-based monitoring is how quickly it provides value:

**Immediate Visibility**: As soon as Cilium agents are deployed, they begin observing network traffic. Within minutes, you'll see network flows appearing in Splunk Observability Cloud through Hubble's flow export.

**Automatic Baselining**: Splunk's ML-powered analytics begin learning normal behavior immediately. While it becomes more accurate over time (usually reaching stable baselines within 24-48 hours), it provides useful anomaly detection even in the first hours.

**No Application Changes**: Because monitoring happens at the kernel level via eBPF, you don't need to modify, rebuild, or redeploy your applications. The monitoring is completely transparent to your workloads.

### Integration with Existing Security Tools

Splunk Observability Cloud with Isovalent is designed to complement, not replace, your existing security infrastructure:

**Splunk Platform Integration**: Network flow data and security events seamlessly integrate with Splunk Enterprise and Splunk Cloud for correlation with other security data, leveraging Splunk's powerful SIEM capabilities.

**Alert Integration**: Splunk Observability Cloud can send alerts to your existing alerting infrastructure - PagerDuty, Slack, email, webhooks, VictorOps, etc.

**Policy Enforcement**: Isovalent provides network policy enforcement through Cilium Network Policies, which are more powerful than standard Kubernetes Network Policies. These policies can be informed by the observed traffic patterns in Splunk, creating a feedback loop between visibility and security enforcement.

## Best Practices for Success

Based on deployment experiences across many organizations, here are best practices for getting the most value from Splunk Observability Cloud with Isovalent:

### 1. Establish Baselines Before Major Changes

Allow the system to run in observation mode for at least a week before making major infrastructure changes. This gives the baseline learning time to understand normal behavior, making anomaly detection more accurate.

### 2. Start with High-Value Namespaces

If you have a large cluster, consider starting with monitoring in specific namespaces that contain critical applications or sensitive data. This allows you to prove value and learn the system before expanding to the entire cluster.

### 3. Correlate Network and Application Data

Make a habit of looking at both APM and Network Monitoring data when investigating issues. Often, the combination provides insights that neither would show alone.

### 4. Use Network Monitoring for Security Reviews

When onboarding new applications or reviewing existing ones, examine their network behavior through Splunk's Network Explorer and Isovalent's Hubble UI. Questions to ask:
- What external destinations does this application communicate with? Are they all expected?
- What infrastructure dependencies does it have? Are they properly documented?
- How does it behave differently in different environments (dev, staging, production)?
- Are there any L7 protocol violations or suspicious API calls visible in Hubble's deep packet inspection?

### 5. Create Custom Alerts for Your Environment

While Splunk Observability Cloud provides sensible default alerts and detectors, customize them for your specific environment. For example:
- Alert if any pod in your production namespace communicates with external destinations outside your approved list
- Alert if network traffic volume for critical services deviates significantly from baseline using Splunk's dynamic thresholds
- Alert if new types of connections appear that haven't been seen before
- Create correlation searches in Splunk that combine network flow data with application traces and infrastructure metrics

### 6. Regular Security Reviews of Network Flows

Schedule regular reviews of network flow maps, particularly for production environments. Look for:
- Unexpected external connections
- Unusual communication patterns between internal services
- Infrastructure dependencies that might not be properly managed or monitored

### 7. Document Expected Behavior

Use the insights from Splunk dashboards and Hubble flow logs to document expected network behavior for your applications. This documentation becomes valuable for:
- Onboarding new team members
- Troubleshooting issues
- Security audits
- Compliance requirements
- Creating Cilium Network Policies based on observed traffic patterns

### 8. Integration into CI/CD

Consider integrating network behavior expectations into your CI/CD pipeline. For example, automated tests could verify that a new version of an application doesn't introduce unexpected network dependencies or communicate with unauthorized destinations.

## The Future of Cloud-Native Observability

eBPF-based network monitoring represents a fundamental shift in how we observe and secure cloud-native applications. As Kubernetes and containerized workloads continue to dominate modern infrastructure, the advantages of kernel-level, context-aware monitoring become even more critical.

### Why This Approach Matters for the Future

**Complexity Management**: As microservices architectures grow more complex with hundreds or thousands of services, understanding the network behavior becomes impossible without automated, comprehensive tooling. eBPF provides this visibility at scale.

**Zero Trust Security**: Modern security models assume no implicit trust, even for internal network traffic. Network monitoring with full visibility into all connections is essential for implementing and verifying zero trust architectures.

**Compliance and Auditing**: Regulatory requirements increasingly demand detailed visibility into data flows and network communications. eBPF-based monitoring provides the comprehensive audit trail needed for compliance.

**Performance Optimization**: As organizations optimize cloud costs, understanding actual network patterns and dependencies helps eliminate waste and improve efficiency.

### The Splunk and Isovalent Advantage

The integration of Splunk Observability Cloud with Isovalent's eBPF-based platform brings together several key advantages:

**No eBPF Expertise Required**: Isovalent—created by the original developers of eBPF and Cilium—handles all the complexity of eBPF programming, verification, and optimization. You benefit from the technology without needing specialized skills, backed by the team that literally invented it.

**Kubernetes-Native**: Both Cilium and Splunk's OpenTelemetry Collector are designed specifically for Kubernetes, using familiar tools and patterns. Cilium is a CNCF graduated project with massive adoption. It feels like a natural part of your Kubernetes infrastructure, not a bolt-on addition.

**Integrated Platform**: Network flow data works seamlessly with Splunk APM, infrastructure monitoring, log analytics, and RUM (Real User Monitoring), providing a unified observability platform rather than disconnected tools. All data flows through OpenTelemetry, the vendor-neutral standard.

**Enterprise-Grade**: Splunk brings decades of data analytics and observability expertise, while Isovalent provides enterprise-hardened Cilium with support. The solution is proven in production at massive scale with companies running thousands of nodes.

## Conclusion

The combination of Splunk Observability Cloud with Isovalent's eBPF-based network monitoring represents a significant leap forward in Kubernetes security and observability. By providing comprehensive, real-time visibility into network traffic at the kernel level while maintaining full Kubernetes context, this integrated solution enables organizations to:

**Detect and Respond to Security Threats**: Comprehensive network visibility means that attacks - from initial reconnaissance through data exfiltration - create observable patterns that security teams can detect and respond to quickly.

**Understand the Complete Picture**: The combination of Isovalent's network monitoring and Splunk APM provides visibility into both application behavior and infrastructure dependencies, eliminating blind spots that exist with either approach alone. Splunk's unified platform correlates traces, metrics, logs, and network flows.

**Maintain Performance**: The efficiency of eBPF ensures that comprehensive monitoring doesn't come at the cost of application performance. You gain visibility without sacrificing the resources your applications need.

**Ensure Compliance**: Detailed network flow data in Splunk provides the audit trail necessary for regulatory compliance and security verification, with long-term retention and powerful search capabilities.

**Optimize Operations**: Understanding actual network patterns and dependencies helps identify optimization opportunities, eliminate waste, and improve overall system efficiency. Splunk's analytics help you understand cost attribution and resource utilization.

As organizations continue to adopt Kubernetes and microservices architectures, the visibility and security provided by eBPF-based network monitoring will become not just valuable, but essential. The dynamic, ephemeral nature of containerized workloads makes traditional monitoring approaches inadequate. eBPF represents the future of observability for cloud-native applications—and Splunk Observability Cloud integrated with Isovalent Enterprise for Cilium brings that future to your Kubernetes clusters today.

Whether you're concerned about security threats, application performance, operational efficiency, or regulatory compliance, Splunk and Isovalent's combined solution provides the visibility and insights you need to run Kubernetes confidently at scale.

## Learn More

Ready to explore Splunk Observability Cloud and Isovalent's eBPF-based network monitoring for your Kubernetes environment? Here are resources to get started:

- [Splunk Observability Cloud for Kubernetes](https://docs.splunk.com/Observability/gdi/opentelemetry/opentelemetry.html) - Complete guide to deploying Splunk OpenTelemetry Collector
- [Isovalent Enterprise for Cilium](https://isovalent.com/product/) - Learn about enterprise Cilium with Hubble observability
- [Cilium Installation Guide](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/) - Deploy Cilium in your Kubernetes cluster
- [Hubble Observability](https://docs.cilium.io/en/stable/gettingstarted/hubble/) - Enable deep network visibility
- [Integrating Cilium with Splunk](https://www.splunk.com/en_us/blog/platform/monitoring-cilium-with-splunk-observability-cloud.html) - Export Hubble flows to Splunk
- [Installing kubectl](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html) - Get started with Kubernetes command-line tools

The future of cloud-native observability is here. With Splunk Observability Cloud and Isovalent, you have the visibility and control you need to secure, optimize, and operate your Kubernetes infrastructure with confidence.
