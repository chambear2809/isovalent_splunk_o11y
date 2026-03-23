# Isovalent + Splunk Observability Cloud — Demo Script

## What We're Trying to Show

This demo tells a story that every ops or platform team has lived through: something is broken, users are complaining, and you have no idea where to start. The journey goes through the usual first stops — APM looks fine, infrastructure looks fine — and then lands on the network layer, where Isovalent's eBPF-powered Hubble observability, flowing into Splunk, reveals the real problem: a DNS overload that was completely invisible to every other tool.

The application we're using is **jobs-app**, a simulated multi-service hiring platform running on Kubernetes. It has a frontend (`recruiter`, `jobposting`), a central API (`coreapi`), a background data pipeline (Kafka + `resumes` + `loader`), and a `crawler` service that periodically makes HTTP calls out to the internet. That last one is going to be our villain today.

---

## Before You Start — Getting the Environment Ready

Do this before anyone is in the room. You want to be set up and sitting at a clean, healthy dashboard when the demo begins — not fiddling with kubectl while people watch.

### Make sure everything is actually running

Run through these checks so you're not surprised mid-demo:

```bash
# Confirm your nodes are healthy
kubectl get nodes

# Confirm Cilium and Hubble are running on both nodes
kubectl get pods -n kube-system | grep -E "(cilium|hubble)"

# Confirm Tetragon is up (good to show even if you don't deep-dive on it)
kubectl get pods -n tetragon

# Confirm the Splunk OTel Collector is running — this is what ships metrics to Splunk
kubectl get pods -n otel-splunk

# Confirm the jobs-app is fully deployed and healthy
kubectl get pods -n tenant-jobs
```

All pods should be in `Running` state before you proceed. If the OTel Collector isn't up, no metrics will appear in Splunk and the whole demo falls apart.

### Reset the app to a healthy baseline

From the `isovalent-demo-jobs-app` directory, make sure the crawler is running at a calm, normal pace — 1 replica, crawling every 0.5 to 5 seconds:

```bash
helm upgrade jobs-app . --namespace tenant-jobs --reuse-values \
  --set crawler.replicas=1 \
  --set crawler.crawlFrequencyLowerBound=0.5 \
  --set crawler.crawlFrequencyUpperBound=5 \
  --set resumes.replicas=1
```

Then **wait at least 5 minutes**. This is important — Splunk needs time to ingest a clean baseline so the spike we're about to create is visually obvious. If you skip this, the charts won't tell a clear story.

### Inject the problem

About 5–10 minutes before the demo starts (or you can do this live for effect), run:

```bash
helm upgrade jobs-app . --namespace tenant-jobs --reuse-values \
  --set crawler.replicas=5 \
  --set crawler.crawlFrequencyLowerBound=0.2 \
  --set crawler.crawlFrequencyUpperBound=0.3 \
  --set resumes.replicas=2
```

Here's what just happened: we scaled the crawler from 1 pod up to 5, and cranked the crawl interval way down to 0.2–0.3 seconds. Each crawler pod makes an HTTP request to `api.github.com`, and every one of those requests needs a DNS lookup first. So instead of 1 pod asking for a DNS resolution every few seconds, you now have 5 pods hammering DNS every fraction of a second. That's something like 15–25 DNS queries per second, sustained, which is enough to start saturating the DNS proxy and causing responses to back up. The knock-on effect is that other services in the namespace that depend on DNS start experiencing intermittent failures — which is exactly what's in our ticket.

---

## The Demo

### Act 1 — A Ticket Shows Up

Start by painting the picture. You don't need to click anything yet — just set the scene.

> *"So it's a normal afternoon and an ITSM ticket comes in. The jobs application team is saying that end users are reporting intermittent 500 errors on the recruiter and job posting pages, and load times have gotten noticeably worse over the last 15 minutes or so. It's been escalated to P2. Let's dig in."*

If you have a way to show the ticket (ServiceNow, Jira, even a screenshot), pull it up:

| | |
|---|---|
| **Ticket** | INC-4072 |
| **Priority** | P2 — High |
| **Summary** | Intermittent failures and slow response times on jobs-app |
| **Description** | Recruiter and job posting pages are returning 500 errors intermittently. Users report page loads have slowed significantly over the last 15 minutes. Engineering has not made any recent deployments. |
| **Reported by** | Application Support Team |
| **Affected namespace** | tenant-jobs |

> *"No recent deployments. That's actually the interesting part — there's no obvious change event to blame. So we need to figure out what changed on our own. Where do we start? APM."*

---

### Act 2 — Check APM First (Dead End #1)

This is where most people would go first, and that's the point. We want to show APM, find it unhelpful, and use that to build the case for needing something deeper.

**Navigate to:** Splunk Observability Cloud → APM → Service Map

The service map for the `tenant-jobs` environment will show the topology: `recruiter` and `jobposting` both call `coreapi`, which connects to Elasticsearch. The `resumes` and `loader` services are communicating over Kafka in the background.

> *"Here's our service map. Every service is lit up — they're all responding, all connected. Let's look at what the numbers are actually saying.*

> *Request rates look normal. Latency is slightly elevated, maybe, but nothing that would explain user-facing errors. Now look at the error rate on coreapi — it's sitting around 10%. You might think that's the problem, but it's actually not. This app has a configurable error rate baked in as part of the demo setup. Ten percent is baseline, not a regression.*

> *So APM is telling us: services are alive, traffic is flowing, and the error rate hasn't changed. There's nothing in the application traces that points to a root cause. Let's try infrastructure."*

---

### Act 3 — Check Infrastructure (Dead End #2)

Same idea here — show infra, find it clean, and let the audience feel the frustration of not having answers yet.

**Navigate to:** Splunk Observability Cloud → Infrastructure → Kubernetes → Cluster: `isovalent-demo`

> *"Let's look at the cluster itself. Maybe something is resource-constrained — a node running hot, pods getting OOMKilled, something like that.*

> *Both nodes look healthy. CPU and memory are well within normal bounds. Drilling into the pods — all of them are in Running state, no restarts, nothing being evicted. The containers themselves aren't hitting their resource limits.*

> *So now we're in a bit of an uncomfortable spot. The ticket says users are seeing errors. APM says the app is running. Infrastructure says the cluster is healthy. Where does that leave us?*

> *This is actually a really common situation. There's a whole class of problems that live below the application layer and below the infrastructure layer — things happening at the network level that traditional monitoring tools simply can't see. DNS failures, connection drops, policy denials, traffic asymmetry. These things don't show up in traces or pod metrics. You need something that can actually observe the network itself. That's where Isovalent comes in."*

---

### Act 4 — The Network Tells the Truth

This is the heart of the demo. Take your time here.

> *"Cilium — which is our CNI, our networking layer running on every node — has a built-in observability component called Hubble. Hubble uses eBPF to watch every single network flow in the cluster in real time. Not sampled, not approximated — every connection, every DNS request, every packet drop. And because we've set up the OpenTelemetry Collector to scrape those Hubble metrics and forward them to Splunk, we can see all of that right here in the same platform we were just looking at for APM and infrastructure.*

> *Let's pull up the Hubble dashboard."*

**Navigate to:** Splunk Observability Cloud → Dashboards → Hubble by Isovalent

---

#### DNS Queries Are Out of Control

**Point to the DNS Queries chart.**

> *"There it is. Look at the DNS query volume — it went off a cliff about 15 minutes ago. That timestamp lines up exactly with when the ticket was opened.*

> *What you're looking at here is `hubble_dns_queries_total`, broken down by source namespace. The spike is entirely coming from `tenant-jobs` — our application namespace. Something in the application started generating a massive amount of DNS traffic, and the DNS proxy started struggling to keep up.*

> *The important thing to understand here is that every single application in the cluster shares the same DNS infrastructure. CoreDNS serves the whole cluster. So when one workload saturates it, everything else that needs name resolution starts getting slow or failing. That's the ripple effect showing up as 500 errors for our users."*

---

#### Top DNS Queries Tell You Exactly What's Causing It

**Point to the Top 10 DNS Queries chart.**

> *"Now let's figure out what's actually making all these DNS requests. The Top 10 DNS Queries chart breaks down the most frequently queried domains, and one name is standing out by a mile: `api.github.com`.*

> *That's not a cluster-internal service. That's an external endpoint — and the only thing in our app that talks to external endpoints is the crawler service. The crawler is designed to periodically make an HTTP call out to an external URL as part of its job simulation. Every time it makes that HTTP call, it needs to resolve `api.github.com` through DNS first.*

> *Normally this isn't a problem. One crawler pod making a request every few seconds is totally fine. But something has clearly changed about how aggressively it's running. We're going to confirm that in a moment."*

---

#### Dropped Flows Show the Blast Radius

**Point to the Dropped Flows chart.**

> *"The Dropped Flows chart is showing something else worth paying attention to. Hubble doesn't just track successful connections — it tracks every connection that gets rejected or dropped, along with a reason code for why. We're seeing a noticeable uptick in drops starting at the same time as the DNS spike.*

> *These drops are the downstream consequence of DNS overload. When services in the namespace try to make connections and DNS is too slow or failing, those connection attempts time out and get dropped. Hubble is capturing all of that. This is what APM was seeing as elevated latency — but APM had no idea it was a DNS problem underneath."*

---

#### Network Flow Volume Confirms the Pattern

**Point to the Network Flows chart.**

> *"And if you look at the overall network flow volume, you can see the total traffic in the namespace has spiked in lockstep with the DNS queries. The crawler workload is generating a disproportionate amount of traffic relative to its normal baseline. This confirms we're not looking at a gradual drift — something changed, and it changed at a specific moment in time."*

---

### Act 5 — Confirming the Root Cause

Now connect the dots and prove it.

> *"So here's the full picture: at some point, the crawler service got scaled up from 1 replica to 5, and its crawl interval got set to something extremely aggressive — every 0.2 to 0.3 seconds. That means you have 5 pods, each firing off a DNS lookup to resolve `api.github.com` multiple times per second. Combined, that's 15 to 25 DNS queries per second, sustained. The DNS proxy wasn't designed to handle that kind of load from a single workload, so it starts queuing, slowing down, and eventually dropping requests. Every other service in the namespace that needs DNS resolution starts getting caught in the crossfire.*

> *Let's just confirm that's actually what we're looking at."*

```bash
# Confirm the current crawler replica count — you'll see 5
kubectl get deploy crawler -n tenant-jobs

# Pull the environment config to see the crawl frequency settings
kubectl get deploy crawler -n tenant-jobs -o jsonpath='{.spec.template.spec.containers[0].env}' | jq .
```

> *"There it is. Five replicas, crawling every 0.2 to 0.3 seconds. This wasn't a code bug, it wasn't an infrastructure failure, and it wasn't a security incident. Someone changed a Helm value — intentionally or accidentally — and the effect was invisible to everything except the network layer.*

> *APM can't see this because it instruments code, not DNS. Infrastructure monitoring can't see this because the pods are healthy — they're doing exactly what they were configured to do. The only tool that could catch this is something operating at the eBPF level, watching every packet, every DNS request, every connection attempt in real time. That's Hubble. And because we've wired it into Splunk, we caught it in the same dashboard we use for everything else."*

---

### Act 6 — Fix It Live

This part is satisfying because you can watch the charts recover in real time.

> *"The fix is straightforward — scale the crawlers back down and restore the normal crawl interval."*

```bash
helm upgrade jobs-app . --namespace tenant-jobs --reuse-values \
  --set crawler.replicas=1 \
  --set crawler.crawlFrequencyLowerBound=0.5 \
  --set crawler.crawlFrequencyUpperBound=5 \
  --set resumes.replicas=1
```

**Go back to the Hubble dashboard and let it sit for a minute.**

> *"Watch the DNS Queries chart. You can see it starting to come back down almost immediately. Within a minute or two it'll be back at baseline. The dropped flows will go to zero. The network flow volume will return to normal.*

> *And on the application side — if we went back to APM right now, we'd see latency normalizing and the error rate settling back to its expected 10% baseline.*

> *We can close the ticket. Root cause: crawler misconfiguration causing DNS saturation. Resolution: reverted crawler replica count and crawl interval via Helm. Time to resolution: about 15 minutes from when the ticket was opened."*

---

### Act 7 — What This Actually Means

End by zooming out and making the value statement feel concrete.

> *"Let's think about what just happened here. We had a real production-style problem — something breaking for end users — and we went through the standard playbook. APM said nothing was wrong. Infrastructure said nothing was wrong. And without Hubble, the next step probably would have been a war room call, people staring at logs, maybe a full restart of the namespace hoping it would go away.*

> *Instead, we found it in under three minutes from the moment we opened the Hubble dashboard. Not because we're smarter, but because we had visibility into the right layer.*

> *The reason this works is eBPF. Cilium's Hubble component hooks into the Linux kernel and observes network events at the source — before they ever reach application code, before they show up in a pod log, before they become a trace in APM. And by shipping those metrics through the OpenTelemetry Collector into Splunk, they sit right alongside your APM data and your infrastructure data in the same platform. You're not switching tools, you're not context-switching between five different dashboards. You add a layer of visibility that wasn't there before, and you keep it in the workflow your team already knows.*

> *That's the story. Network observability isn't a niche need — it's the gap that APM and infrastructure monitoring leave behind. Isovalent fills that gap, and Splunk is where you see it."*

---

## Quick Reference

**Inject the problem** (run ~10 min before demo):
```bash
helm upgrade jobs-app . -n tenant-jobs --reuse-values \
  --set crawler.replicas=5 \
  --set crawler.crawlFrequencyLowerBound=0.2 \
  --set crawler.crawlFrequencyUpperBound=0.3 \
  --set resumes.replicas=2
```

**Remediate** (run live in Act 6):
```bash
helm upgrade jobs-app . -n tenant-jobs --reuse-values \
  --set crawler.replicas=1 \
  --set crawler.crawlFrequencyLowerBound=0.5 \
  --set crawler.crawlFrequencyUpperBound=5 \
  --set resumes.replicas=1
```

**Confirm the misconfiguration:**
```bash
kubectl get deploy crawler -n tenant-jobs
kubectl get deploy crawler -n tenant-jobs -o jsonpath='{.spec.template.spec.containers[0].env}' | jq .
```

**Key Splunk navigation path:**
APM → Service Map → (show it's clean) → Infrastructure → Kubernetes → (show it's clean) → Dashboards → Hubble by Isovalent → (show the DNS spike)

## Timing Guide

| Section | Approx. Time |
|---|---|
| Act 1 — The Ticket | ~1 min |
| Act 2 — APM (dead end) | ~2–3 min |
| Act 3 — Infrastructure (dead end) | ~1–2 min |
| Act 4 — Hubble Dashboards | ~4–5 min |
| Act 5 — Root Cause Confirmation | ~2 min |
| Act 6 — Fix It Live | ~2 min |
| Act 7 — Value Wrap-Up | ~2 min |
| **Total** | **~14–17 min** |
