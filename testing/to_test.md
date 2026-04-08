# Products to Test — Prioritised

Priority is based on weighted value (60% blue, 30% green, 10% red) balanced against setup difficulty for the Docker-based testing stack.

---

## Tier 1 — Deploy First (High value, easy setup)

- ~~**CrowdSec**~~ — **DEPLOYED** → `testing/crowdsec/`

- ~~**DFIR-IRIS**~~ — **DEPLOYED** → `testing/iris/`

- **BloodHound** — Setup: 3/10 | Value: 8/10 | Priority Score: ★★★★★
  Graph-based Active Directory attack path mapping tool that reveals hidden privilege relationships and lateral movement opportunities. Uses SharpHound/AzureHound collectors to enumerate AD objects into a Neo4j database, enabling red teams to discover attack chains and blue teams to identify privilege risks.
  GitHub (CE): https://github.com/SpecterOps/BloodHound
  GitHub (Legacy): https://github.com/SpecterOps/BloodHound-Legacy
  Docs: https://bloodhound.specterops.io/get-started/introduction
  Docker: `specterops/bloodhound` on Docker Hub; docker-compose in repo at `examples/docker-compose/`
  _Setup notes: Official docker-compose provided in repo (BloodHound CE). PostgreSQL + Neo4j + BloodHound containers. Web UI proxies cleanly through Traefik. Well-documented setup process._
  _Value notes: Blue 7/10 — identify AD privilege risks proactively, find misconfigs. Green 8/10 — validate AD attack paths, measure hardening. Red 9/10 — essential for AD attack planning. Dual-use tool with massive value on both sides — one of the best bang-for-buck tools on this list._

- **Caldera** — Setup: 4/10 | Value: 8/10 | Priority Score: ★★★★★
  MITRE's automated adversary emulation platform built on the ATT&CK framework. Simulates real-world threats, tests network and host defenses, and automates red team operations through a C2 server with REST API and web interface. Supports plugins for custom agents, reporting, and TTPs.
  GitHub: https://github.com/mitre/caldera
  Docs: https://caldera.readthedocs.io/
  Website: https://caldera.mitre.org/
  Docker: `mitre/caldera` on Docker Hub; docker-compose in repo
  _Setup notes: Official Docker image and compose in repo. Mostly self-contained (embedded DB). Web UI on single port — clean Traefik integration. Agent communication ports need direct exposure. Plugin system may require volume mounts. Well-documented._
  _Value notes: Blue 7/10 — automated detection testing against ATT&CK. Green 10/10 — automated adversary emulation, runs Atomic Red Team tests. Red 7/10 — automated attack execution. MITRE-backed, integrates with Atomic Red Team — the automated purple team engine._

- **Shuffle** — Setup: 4/10 | Value: 8/10 | Priority Score: ★★★★★
  Open-source SOAR platform for automating security workflows and enabling teams to respond to threats faster with minimal human intervention. Provides playbook-driven automation with extensive integrations, no specialized coding knowledge required.
  GitHub: https://github.com/Shuffle/Shuffle
  Docs: https://shuffler.io/docs
  Website: https://shuffler.io/
  Docker: `frikky/shuffle` on Docker Hub; docker-compose in repo
  _Setup notes: Official docker-compose in repo. Backend + Frontend + Orborus (executor) + OpenSearch containers. Well-documented Docker setup. Web UI on single port — clean Traefik integration. Needs Docker socket mount for workflow execution (security consideration)._
  _Value notes: Blue 9/10 — SOAR automation, playbook-driven response, 100+ integrations. Green 7/10 — automate exercise workflows. Red 1/10. More mature than Tracecat, larger community. Pick one SOAR — Shuffle is easier to set up, Tracecat is more modern._

- **SonarQube** — Setup: 2/10 | Value: 7/10 | Priority Score: ★★★★★
  Automated code quality and security scanning platform that detects bugs, vulnerabilities, code smells, and technical debt across 40+ programming languages. Uses static analysis with 6,000+ language-specific rules.
  GitHub: https://github.com/SonarSource/sonarqube
  Docs: https://docs.sonarsource.com/sonarqube
  Website: https://www.sonarsource.com/products/sonarqube/
  Docker: `sonarqube` (official image on Docker Hub)
  _Setup notes: Official Docker image + PostgreSQL is all you need. Well-documented docker-compose examples. Web UI on a single port — easy Traefik integration. Minimal config required._
  _Value notes: Blue 7/10 — catches vulnerabilities before production, shift-left security. Green 8/10 — code compliance, security policy enforcement. Red 2/10 — can reveal attack surface. Proactive defense with high ROI._

- **Nuclei** — Setup: 3/10 | Value: 7/10 | Priority Score: ★★★★★
  Fast, customizable vulnerability scanner powered by a YAML-based DSL for detecting vulnerabilities in applications, APIs, networks, and cloud configurations. Supports multiple protocols (HTTP, DNS, TCP, SSL) with 6,500+ community-contributed templates for real-world exploits. Prioritizes zero false positives.
  GitHub: https://github.com/projectdiscovery/nuclei
  Docs: https://docs.projectdiscovery.io/opensource/nuclei/overview
  Website: https://projectdiscovery.io/nuclei
  Docker: `projectdiscovery/nuclei` on Docker Hub
  _Setup notes: Single container CLI tool. No web UI — runs as a command-line scanner. No Traefik integration needed. Mount template volumes and output dirs. Simple to containerise but "production" means scheduled scans rather than a persistent service._
  _Value notes: Blue 6/10 — proactive vuln scanning with community templates. Green 8/10 — validate security posture across infra. Red 7/10 — exploit validation. 6,500+ templates make it incredibly versatile. Complements ZAP (broader protocol support)._

- **VECTR** — Setup: 3/10 | Value: 7/10 | Priority Score: ★★★★★
  Purple team tracking and reporting tool by Security Risk Advisors for recording red and blue team testing activities to measure detection and prevention capabilities. Provides centralized management of assessment groups, campaigns, and test cases aligned to adversary threats.
  GitHub: https://github.com/SecurityRiskAdvisors/VECTR
  Docs: https://docs.vectr.io
  Docker: `securityriskadvisors/vectr_tomcat` on Docker Hub
  _Setup notes: Official docker-compose in repo. Tomcat + MongoDB containers. Web UI on single port — straightforward Traefik integration. Well-documented setup with .env config. Lightweight resource requirements._
  _Value notes: Blue 6/10 — measure detection coverage gaps. Green 10/10 — core purple team tracking, ATT&CK-aligned reporting. Red 5/10 — track attack success. Purpose-built for purple team exercises — exactly what a green team needs._

## Tier 2 — Deploy Soon (High value, moderate setup)

- **Graylog** — Setup: 5/10 | Value: 9/10 | Priority Score: ★★★★
  Centralized log management and SIEM platform that collects, stores, and analyzes log data from multiple sources in real-time. Provides security threat detection, investigation capabilities, and flexible deployment (cloud, on-prem, or hybrid).
  GitHub: https://github.com/Graylog2/graylog2-server
  Docs: https://docs.graylog.org/
  Website: https://graylog.org/
  Docker: `graylog/graylog` on Docker Hub
  _Setup notes: Requires MongoDB + OpenSearch/Elasticsearch + Graylog (3 containers minimum). Official compose examples exist. Web UI proxies fine through Traefik. Needs syslog/GELF input ports exposed directly (not via Traefik). OpenSearch tuning (JVM heap, ulimits) similar to existing Elastic stack._
  _Value notes: Blue 10/10 — centralised log management is foundational for detection and response. Green 8/10 — log-based detection validation during exercises. Red 1/10. Already have Elastic/Wazuh stacks — Graylog is an alternative SIEM, complements or replaces those._

- **MISP** — Setup: 6/10 | Value: 9/10 | Priority Score: ★★★★
  Open-source threat intelligence platform for collecting, storing, and sharing cyber security indicators and malware analysis data. Provides automated correlation of IOCs, structured data exchange via STIX/TAXII, and real-time synchronization across multiple MISP instances.
  GitHub: https://github.com/MISP/MISP
  Docs: https://www.misp-project.org/documentation/
  Website: https://www.misp-project.org/
  Docker: https://github.com/MISP/misp-docker
  _Setup notes: Official misp-docker repo exists but MISP is a complex PHP app with many dependencies (MySQL, Redis, modules workers). Docker setup has lots of env vars and init steps. Known for being finicky to get right. Web UI proxies through Traefik fine. Production hardening (GPG keys, sync config, modules) adds complexity._
  _Value notes: Blue 10/10 — IOC management, threat intel sharing, correlation engine. Green 8/10 — threat-informed defense planning. Red 2/10 — understand target's defenses. Industry standard TIP — feeds into Suricata, SIEM, DFIR-IRIS. Central hub for threat intelligence._

- **Tracecat** — Setup: 5/10 | Value: 8/10 | Priority Score: ★★★★
  Open-source security automation platform (SOAR alternative) for building end-to-end automations combining workflows, agents, cases, and integrations. Features a low-code workflow builder with 100+ pre-built connectors, sandboxed execution via nsjail, and durable workflow orchestration with Temporal.
  GitHub: https://github.com/TracecatHQ/tracecat
  Docs: https://docs.tracecat.com/introduction
  Website: https://www.tracecat.com/
  Docker: `ghcr.io/tracecathq/tracecat` on GitHub Container Registry
  _Setup notes: Multiple containers (API + worker + UI + Temporal + PostgreSQL). Official docker-compose in repo. Newer project so Docker setup is still maturing. Web UI proxies through Traefik. Temporal adds operational complexity._
  _Value notes: Blue 9/10 — automated incident response, playbook-driven remediation. Green 7/10 — automate exercise workflows. Red 1/10. SOAR is a force multiplier for small teams — automates repetitive SOC tasks. Newer alternative to Shuffle with modern architecture. (Pick Shuffle OR Tracecat — not both.)_

- **OpenVAS / Greenbone** — Setup: 6/10 | Value: 8/10 | Priority Score: ★★★★
  Open-source vulnerability assessment scanner that performs unauthenticated and authenticated security testing against target systems. Executes Vulnerability Tests using daily-updated feeds from the Greenbone Community Feed. Core component of Greenbone Vulnerability Manager (GVM).
  GitHub: https://github.com/greenbone/openvas-scanner
  Docs: https://greenbone.github.io/docs/latest/background.html
  Website: https://www.openvas.org/
  Docker: `immauss/openvas` on Docker Hub (community-maintained, includes docker-compose)
  _Setup notes: Full GVM stack has many components (gvmd, openvas-scanner, gsad, ospd-openvas, redis, PostgreSQL). Community all-in-one image simplifies this but isn't truly production-grade. Initial NVT feed sync takes 30+ minutes. Web UI (GSA) proxies through Traefik. Resource-heavy._
  _Value notes: Blue 8/10 — vulnerability management, compliance scanning, asset risk scoring. Green 9/10 — continuous posture assessment. Red 5/10 — identify targets. Industry standard vulnerability scanner — essential for any mature security program._

- **BunkerWeb** — Setup: 6/10 | Value: 8/10 | Priority Score: ★★★★
  Open-source Web Application Firewall (WAF) and reverse proxy that shields web services from OWASP Top 10 attacks, malicious bots, and DDoS. Built on NGINX with integrated ModSecurity and modular design, works in Docker, Kubernetes, and Linux environments.
  GitHub: https://github.com/bunkerity/bunkerweb
  Docs: https://docs.bunkerweb.io
  Website: https://www.bunkerweb.io
  Docker: `bunkerity/bunkerweb` on Docker Hub
  _Setup notes: BunkerWeb IS a reverse proxy — it would compete with or sit alongside Traefik, creating architectural complexity. Multiple containers (bunkerweb + scheduler + UI + database). Needs careful network config to avoid conflicts with existing Traefik routing._
  _Value notes: Blue 9/10 — OWASP Top 10 protection, bot blocking, DDoS mitigation. Green 7/10 — hardening validation, WAF testing. Red 1/10. Core defensive infrastructure — high blue team value. (Pick BunkerWeb OR SafeLine — not both.)_

- **Smallstep Certificates** — Setup: 5/10 | Value: 7/10 | Priority Score: ★★★★
  Private certificate authority (X.509 & SSH) and ACME server that automates certificate management with short-lived, automatically-renewed credentials. Consolidates identity for workloads, devices, and people, enabling zero-trust security at scale.
  GitHub: https://github.com/smallstep/certificates
  Docs: https://smallstep.com/docs/step-ca/
  Website: https://smallstep.com/certificates
  Docker: `smallstep/step-ca` on Docker Hub (also `smallstep/step-ca-hsm` for HSM-backed keys)
  _Setup notes: Single container but requires PKI initialization (step ca init) before first run. Needs careful volume management for keys/certs. ACME endpoint can sit behind Traefik. Conceptually simple but PKI config has a learning curve if unfamiliar._
  _Value notes: Blue 8/10 — zero-trust cert management, mTLS between services, short-lived creds. Green 8/10 — PKI hardening, certificate lifecycle. Red 1/10. Foundational infrastructure security — enables zero-trust architecture._

- **ZAP (Zed Attack Proxy)** — Setup: 4/10 | Value: 7/10 | Priority Score: ★★★★
  Free, open-source web application security scanner by Checkmarx that automatically identifies vulnerabilities during development and testing, and supports manual penetration testing. One of the world's most widely used web app scanners, available as desktop app and containerized for CI/CD.
  GitHub: https://github.com/zaproxy/zaproxy
  Docs: https://www.zaproxy.org/docs/
  Website: https://www.zaproxy.org/
  Docker: `zaproxy/zap-stable` and `zaproxy/zap-bare` on Docker Hub
  _Setup notes: Single container. Official Docker images are well-maintained. For persistent/daemon mode, needs `zap.sh -daemon` with API enabled. Web UI can be proxied through Traefik. Primarily a scanning tool — "production" means persistent API mode rather than one-shot scans._
  _Value notes: Blue 6/10 — proactive web vuln scanning. Green 8/10 — validate web app security posture. Red 7/10 — penetration testing tool. Strong dual-use value for continuous web app security assessment._

- **PurpleOps** — Setup: 3/10 | Value: 7/10 | Priority Score: ★★★★
  Open-source, self-hosted purple team management platform for tracking security exercises by coordinating red team attacks with blue team detections. Centralizes assessment data aligned with MITRE ATT&CK to identify coverage gaps and measure defensive posture.
  GitHub: https://github.com/CyberCX-STA/PurpleOps
  Docs: https://docs.purpleops.app/
  Website: https://purpleops.app/
  Docker: Containers available via GitHub repo
  _Setup notes: Docker-compose in repo. Simple stack (app + MongoDB). Web UI on single port — easy Traefik integration. Lightweight and straightforward to deploy._
  _Value notes: Blue 6/10 — track defensive coverage. Green 10/10 — ATT&CK-aligned exercise management. Red 5/10 — track attack progress. Similar role to VECTR — pick one. PurpleOps is simpler, VECTR has more features. (Pick VECTR OR PurpleOps — not both.)_

- **GoPhish** — Setup: 3/10 | Value: 6/10 | Priority Score: ★★★★
  Open-source phishing simulation framework (Go) for security awareness training and penetration testing. Provides a web UI for designing templates, managing target groups, executing campaigns, and analyzing results in real time (opens, clicks, data submissions).
  GitHub: https://github.com/gophish/gophish
  Website: https://getgophish.com/
  Docker: `gophish/gophish` on Docker Hub
  _Setup notes: Single container with embedded SQLite database. Admin UI and phishing landing page on separate ports — both can be Traefik-routed. Needs SMTP config for sending emails. Clean, simple setup. Landing page port needs its own Traefik router._
  _Value notes: Blue 5/10 — security awareness metrics, identify phishing-susceptible users. Green 8/10 — test email filtering and user awareness. Red 7/10 — phishing campaign tool. Strong green team value for measuring human-layer defenses._

- **ClamAV** — Setup: 2/10 | Value: 6/10 | Priority Score: ★★★★
  Open-source antivirus engine that detects trojans, viruses, malware, and other malicious threats. Industry standard for mail gateway scanning with multi-threaded daemon scanning, automatic signature updates, and support for multiple file formats and archives.
  GitHub: https://github.com/Cisco-Talos/clamav
  Docs: https://docs.clamav.net
  Website: https://www.clamav.net
  Docker: `clamav/clamav` (Alpine-based) and `clamav/clamav-debian` on Docker Hub
  _Setup notes: Single container daemon. No web UI (API/socket-based), so no Traefik routing needed — just runs as a backend service. Official Docker image is well-maintained. Initial signature download takes a few minutes on first start._
  _Value notes: Blue 7/10 — malware detection for file uploads, email scanning. Green 6/10 — endpoint security validation. Red 1/10. Solid defensive layer but signature-based — limited against advanced threats._

## Tier 3 — Deploy When Ready (High value, hard setup)

- **Suricata** — Setup: 7/10 | Value: 9/10 | Priority Score: ★★★
  Open-source network IDS, IPS, and Network Security Monitoring engine developed by the Open Information Security Foundation (OISF). Inspects network traffic against rule-based signatures to detect and optionally block threats, operating in high-performance multi-threaded mode capable of handling multi-gigabit flows.
  GitHub: https://github.com/OISF/suricata
  Docs: https://docs.suricata.io/
  Website: https://suricata.io/
  Docker: `jasonish/suricata` on Docker Hub (community-maintained, de facto standard)
  _Setup notes: Requires `network_mode: host` or `NET_ADMIN` + `NET_RAW` capabilities for packet capture — breaks standard Docker networking model. Rule management (suricata-update) needs config. No web UI (outputs logs/eve.json). Production setup typically pairs with Elasticsearch + Kibana for visualization. Community Docker image only._
  _Value notes: Blue 10/10 — network IDS/IPS is a cornerstone of defensive security. Green 8/10 — validate network detections against attack traffic. Red 1/10. Industry standard NIDS — feeds into existing Elastic/Wazuh stacks. Hard to set up in Docker but extremely valuable._

- **Malcolm** — Setup: 8/10 | Value: 9/10 | Priority Score: ★★★
  Network traffic analysis tool suite developed by CISA and Idaho National Laboratory for analyzing PCAP files, Zeek logs, and Suricata alerts. Provides threat detection, visualization, and forensic capabilities through integrated tools like Arkime, OpenSearch Dashboards, and Zeek.
  GitHub: https://github.com/cisagov/Malcolm
  Docs: https://cisagov.github.io/Malcolm/
  Website: https://malcolm.fyi
  Docker: `ghcr.io/idaholab/malcolm/*` on GitHub Container Registry
  _Setup notes: Massive stack — 10+ containers (Arkime, OpenSearch, Zeek, Suricata, Logstash, Filebeat, dashboards, API, nginx, etc.). Has its own docker-compose but it's a full opinionated platform. Very resource-heavy (16GB+ RAM recommended). Own nginx proxy conflicts with Traefik. Packet capture needs host network access. Better suited as a standalone deployment than integrated into the testing stack._
  _Value notes: Blue 10/10 — complete NSM suite (Arkime + Zeek + Suricata + dashboards in one). Green 8/10 — full network visibility for exercises. Red 1/10. CISA-backed, production-proven. Replaces deploying Arkime + Suricata + Zeek separately — but at the cost of massive complexity and resources. (Consider Malcolm OR Arkime+Suricata separately — not both.)_

- **OpenCTI** — Setup: 7/10 | Value: 8/10 | Priority Score: ★★★
  Open-source cyber threat intelligence platform that structures, stores, and visualizes technical and non-technical threat information using STIX2 standards. Integrates with MISP, TheHive, and MITRE ATT&CK. Originally developed by ANSSI and CERT-EU, now managed by Filigran.
  GitHub: https://github.com/OpenCTI-Platform/opencti
  Docs: https://docs.opencti.io/latest/
  Website: https://filigran.io/platforms/opencti/
  Docker: https://hub.docker.com/u/opencti | https://github.com/OpenCTI-Platform/docker
  _Setup notes: Heavy multi-container stack: OpenCTI platform + worker + connector(s) + Elasticsearch/OpenSearch + Redis + RabbitMQ + MinIO. Official docker-compose helper repo exists but has many services and env vars. Resource-hungry (8GB+ RAM recommended). Web UI proxies through Traefik. Complex but well-documented._
  _Value notes: Blue 9/10 — STIX2 threat intelligence, ATT&CK mapping, relationship graphing. Green 8/10 — threat-informed defense. Red 2/10. More modern UI than MISP, better visualisation. Can sync with MISP — complementary rather than competing. (Pick MISP OR OpenCTI to start — can add the other later.)_

- **Arkime** — Setup: 7/10 | Value: 8/10 | Priority Score: ★★★
  Open-source, large-scale full packet capture and search system (formerly Moloch) that stores and indexes network traffic in standard PCAP format. Comprises a capture agent, Node.js viewer web interface, and OpenSearch/Elasticsearch backend. Scales to handle tens of gigabits per second.
  GitHub: https://github.com/arkime/arkime
  Docs & Website: https://arkime.com/
  Docker: Official images at `ghcr.io/arkime/arkime/arkime`; community images on Docker Hub
  _Setup notes: Capture + Viewer + OpenSearch/Elasticsearch (3+ containers). Capture needs `network_mode: host` or `NET_ADMIN` for packet capture — breaks standard Docker networking. Viewer web UI proxies through Traefik. OpenSearch tuning required (similar to Elastic stack). PCAP storage needs large volumes. Official Docker support is relatively new._
  _Value notes: Blue 9/10 — full packet capture is irreplaceable for forensics and incident investigation. Green 7/10 — analyse exercise traffic. Red 1/10. Network forensics capability you can't get from logs alone — complements SIEM data with raw packets. (Consider Malcolm instead if you want Arkime + Suricata + Zeek bundled.)_

- **Atomic Red Team** — Setup: 8/10 (doesn't fit Docker pattern) | Value: 8/10 | Priority Score: ★★★
  Library of portable, reproducible tests mapped to MITRE ATT&CK techniques, maintained by Red Canary. Tests run directly from the command line to validate defensive capabilities, typically completing in under five minutes with no installation required.
  GitHub: https://github.com/redcanaryco/atomic-red-team
  Website: https://www.atomicredteam.io/
  Docker: Script-based (YAML/shell tests executed directly; no Docker containers required)
  _Setup notes: Not a containerised service — it's a library of test scripts run on endpoints. No Docker images, no web UI, no compose file. Would need a custom wrapper container to fit the stack pattern. Better deployed directly on target hosts or integrated with Caldera. Does not match the testing stack architecture._
  _Value notes: Blue 7/10 — validate detection rules against known TTPs. Green 10/10 — the gold standard for ATT&CK technique testing. Red 6/10 — test library. Extremely valuable for measuring detection coverage — best paired with Caldera for automation. High value despite poor Docker fit._

- **SafeLine** — Setup: 5/10 | Value: 7/10 | Priority Score: ★★★
  Self-hosted Web Application Firewall (WAF) and reverse proxy by Chaitin Tech that protects against SQL injection, XSS, RCE, path traversal, and more. Uses semantic analysis and machine learning to detect zero-day exploits with 99.995% detection rate. Deployable via Docker Compose.
  GitHub: https://github.com/chaitin/SafeLine
  Website: https://waf.chaitin.com/
  Docker: `chaitin/safeline-*` images on Docker Hub; docker-compose in repo
  _Setup notes: Official docker-compose provided. Multiple containers (mgt, detector, postgres, nginx, etc.). Like BunkerWeb, it's a reverse proxy/WAF so it sits in front of or alongside Traefik — architectural decision needed. Their compose is opinionated and may need reworking to fit the testing stack pattern._
  _Value notes: Blue 8/10 — ML-powered WAF, zero-day detection. Green 7/10 — test WAF bypass techniques. Red 1/10. Similar role to BunkerWeb — pick one. ML approach may catch more novel attacks but is less transparent than ModSecurity rules. (Pick BunkerWeb OR SafeLine — not both.)_

## Tier 4 — Nice to Have (Moderate value, easy setup)

- **Scanopy** — Setup: 4/10 | Value: 6/10 | Priority Score: ★★
  Automated network discovery and diagramming tool that deploys a lightweight daemon to discover hosts, map network connections, and identify 230+ services. Uses SNMP, LLDP, CDP, and ARP protocols to automatically generate and maintain live network topology diagrams, supporting export to SVG, PNG, or Mermaid formats.
  GitHub: https://github.com/scanopy/scanopy
  Docs: https://scanopy.net/docs
  Website: https://scanopy.net/
  Docker: Images available via standard Docker registries
  _Setup notes: Docker images available but less mature documentation than major projects. Needs host network access for protocol discovery (SNMP, LLDP, ARP) which requires `network_mode: host` or macvlan — slightly tricky with Traefik routing._
  _Value notes: Blue 6/10 — asset discovery, network visibility, rogue device detection. Green 7/10 — validate network segmentation. Red 3/10 — recon. You can't defend what you can't see — asset inventory is a foundational capability._

- **GitLab** — Setup: 3/10 | Value: 5/10 | Priority Score: ★★
  Open-source DevOps platform combining Git hosting, CI/CD pipelines, issue tracking, and container registry. Provides complete control over source code, automation, and project management when self-hosted.
  GitHub: https://github.com/gitlabhq/gitlabhq
  Source: https://gitlab.com/gitlab-org/gitlab
  Docs: https://docs.gitlab.com
  Website: https://about.gitlab.com
  Docker: `gitlab/gitlab-ce` on Docker Hub
  _Setup notes: Already have a testing/gitlab stack. Official Docker image is well-documented. Production setup needs PostgreSQL + Redis + GitLab + Runner containers. Straightforward Traefik integration via labels. Heavy on RAM (~4GB minimum)._
  _Value notes: Blue 5/10 — CI/CD for security tooling, built-in SAST/DAST. Green 7/10 — IaC management, pipeline security testing. Red 1/10 — not an offensive tool. Useful infrastructure but not a core security platform._

- **Pi-hole** — Setup: 3/10 | Value: 5/10 | Priority Score: ★★
  Network-level DNS sinkhole that blocks advertisements and internet trackers across your entire network without requiring client-side software. Acts as a DNS server comparing queries against blocklists, protecting all connected devices. Lightweight enough to run on a Raspberry Pi.
  GitHub: https://github.com/pi-hole/pi-hole
  Docs: https://docs.pi-hole.net/
  Website: https://pi-hole.net/
  Docker: `pihole/pihole` on Docker Hub
  _Setup notes: Single container with excellent Docker support. Web admin UI routes through Traefik easily. DNS ports (53 TCP/UDP) need direct host exposure — can't go through Traefik. May conflict with host DNS resolver. Well-documented env vars._
  _Value notes: Blue 6/10 — block malicious domains, DNS-level threat blocking, DNS query logging. Green 5/10 — test DNS-based detections. Red 1/10. Useful DNS filtering layer but limited compared to a full DNS security solution._

- **Mythic** — Setup: 5/10 | Value: 5/10 | Priority Score: ★★
  Open-source, multiplayer C2 framework built on microservices (Golang, RabbitMQ, PostgreSQL, React). Enables collaborative red team operations with a modular architecture supporting customizable agents, multiple communication channels (HTTP/S, DNS, WebSockets), RBAC, OPSEC checks, and Python scripting.
  GitHub: https://github.com/its-a-feature/Mythic
  Docs: https://docs.mythic-c2.net/home
  Docker: Containerized via Docker Compose; `specterops/mythic` on Docker Hub
  _Setup notes: Built for Docker from the ground up — uses its own mythic-cli to manage docker-compose. Many containers (server, rabbitmq, postgres, each agent type is a container). Web UI proxies through Traefik. C2 listener ports need direct exposure. The mythic-cli tooling may conflict with custom compose management — needs adaptation to fit the stack pattern._
  _Value notes: Blue 2/10 — understand C2 patterns. Green 6/10 — best C2 for testing detections (web UI + logging). Red 9/10 — modular, extensible C2. Higher green team value than other C2s due to web UI and detailed operation logging. If picking one C2 for detection testing, this is the best choice._

- **Rocket.Chat** — Setup: 2/10 | Value: 4/10 | Priority Score: ★★
  Open-source, self-hosted team messaging platform providing real-time chat, file sharing, video conferencing, and collaboration tools with end-to-end encryption and SSO integration. Supports LDAP/SAML and compliance with GDPR, HIPAA, and SOC 2.
  GitHub: https://github.com/RocketChat/Rocket.Chat
  Website: https://www.rocket.chat/
  Docs: https://docs.rocket.chat/
  Docker: `rocket.chat` (official image on Docker Hub)
  _Setup notes: Official Docker image + MongoDB. Well-documented compose examples. Single web port — clean Traefik integration. Straightforward env config._
  _Value notes: Blue 4/10 — secure SOC comms, incident coordination. Green 4/10 — team coordination during exercises. Red 2/10 — minimal. Useful for ops but not a security tool itself._

- **PrivateBin** — Setup: 1/10 | Value: 3/10 | Priority Score: ★★
  Zero-knowledge encrypted pastebin where content is encrypted/decrypted entirely in the browser using 256-bit AES. The server never has access to paste data. Supports password protection, expiration/burn-after-reading, syntax highlighting, file uploads, and discussions.
  GitHub: https://github.com/PrivateBin/PrivateBin
  Website: https://privatebin.info/
  Docker: `privatebin/privatebin` on Docker Hub
  _Setup notes: Single container, no database required (file-based storage). One port, perfect Traefik integration. Minimal config. Could be production-ready in minutes._
  _Value notes: Blue 3/10 — secure data sharing for IR teams. Green 3/10 — share findings during exercises. Red 3/10 — exfil staging. Nice-to-have utility, not a security tool._

## Tier 5 — Low Priority (Low value or poor Docker fit)

- **Adversary Emulation Library** — Setup: 9/10 (not Docker) | Value: 7/10 | Priority Score: ★
  Open collection of adversary emulation plans by MITRE's Center for Threat-Informed Defense that model specific named adversaries (APT29, FIN6, FIN7, Carbanak, Turla, etc.) from initial access through exfiltration. Plans are rooted in public intelligence reports with compiled binaries, source code, and step-by-step documentation. Can integrate with CALDERA for automation.
  GitHub: https://github.com/center-for-threat-informed-defense/adversary_emulation_library
  Website: https://ctid.mitre.org/resources/adversary-emulation-library/
  Docker: No containers — plans run as scripts/procedures on endpoints
  _Setup notes: Not a service — it's a documentation/script library. No containers, no web UI, no compose file. Plans are executed on target endpoints, not deployed as infrastructure. Best used as a reference alongside Caldera. Does not fit the testing stack pattern at all._
  _Value notes: Blue 6/10 — understand real APT TTPs. Green 9/10 — realistic emulation plans for exercises. Red 7/10 — proven attack chains. High-quality MITRE-backed content — feeds into Caldera. Valuable as reference material even if it can't be containerised._

- **OPNsense** — Setup: 10/10 (not Docker) | Value: 9/10 | Priority Score: ★
  Open-source firewall and routing platform providing enterprise-grade network security including stateful IPv4/IPv6 firewalling, multi-WAN load balancing, VPN support (IPsec, OpenVPN, WireGuard), hardware failover, and intrusion prevention via Suricata. Primarily designed for VM and bare-metal deployment; Docker containers are community-maintained only.
  GitHub: https://github.com/opnsense/core
  Docs: https://docs.opnsense.org/
  Website: https://opnsense.org/
  _Setup notes: OPNsense is a full OS (FreeBSD-based) — it cannot run in Docker containers. Requires a VM or bare-metal. Community Docker attempts use KVM-in-Docker which is hacky and not production-grade. Does not fit the existing testing stack pattern at all._
  _Value notes: Blue 10/10 — enterprise firewall, IDS/IPS, network segmentation. Green 8/10 — firewall rule validation, network hardening. Red 1/10. Incredibly valuable for defense but cannot be deployed in Docker — needs separate VM infrastructure._

- **Sliver** — Setup: 6/10 | Value: 4/10 | Priority Score: ★
  Open-source cross-platform adversary emulation framework by BishopFox, designed as an alternative to Cobalt Strike. Supports C2 communication over mTLS, WireGuard, HTTP(S), and DNS with per-binary asymmetric encryption. Implants run on Windows, macOS, and Linux with multiplayer collaboration support.
  GitHub: https://github.com/BishopFox/sliver
  Website: https://bishopfox.com/tools/sliver
  Docker: Community images at `warhorse/sliver` on Docker Hub
  _Setup notes: Community Docker images only — no official compose. CLI-based (no web UI) so no Traefik routing for management. C2 listener ports need direct host exposure. Multiplayer mode adds config. Implant generation needs volume persistence. Armory plugin system may need internet access from container._
  _Value notes: Blue 2/10 — understand C2 traffic patterns. Green 5/10 — test C2 detections. Red 9/10 — top-tier open-source C2. Primarily offensive — green team value is testing whether detections catch C2 traffic. Overlaps with Havoc, Mythic, Covenant._

- **Chef** — Setup: 8/10 | Value: 5/10 | Priority Score: ★
  Declarative infrastructure and configuration management engine that transforms infrastructure into code, automating how configurations are deployed and managed at any scale. Consists of Chef Infra (node configuration), Chef Infra Server (centralized policy hub), and Chef Automate (enterprise visibility and compliance).
  GitHub: https://github.com/chef
  Website: https://www.chef.io/
  Docker: `chef/chef` on Docker Hub
  _Setup notes: Production Chef requires Chef Server + Chef Automate + PostgreSQL + Elasticsearch — complex multi-container setup. Docker images exist but Chef is primarily designed for VM/bare-metal deployment. No official docker-compose. Chef Server container configuration is notoriously fiddly. Licensing changes add complexity._
  _Value notes: Blue 5/10 — enforce security baselines, compliance as code. Green 7/10 — infrastructure hardening validation. Red 1/10. Already have Puppet in the testing stack — overlapping role. High effort for marginal gain over existing config management._

- **Havoc** — Setup: 7/10 | Value: 3/10 | Priority Score: ★
  Modern, malleable C2 framework for post-exploitation operations. Features a cross-platform UI (C++/Qt), a Go-based backend with multiplayer support, and the Demon agent (C) with advanced evasion techniques like sleep obfuscation and indirect syscalls. Provides HTTP/HTTPS listeners and customizable C2 profiles.
  GitHub: https://github.com/HavocFramework/Havoc
  Website & Docs: https://havocframework.com/ | https://havocframework.com/docs/installation
  Docker: Dockerfiles in the main repo; community image `dingdayu/havoc` on Docker Hub
  _Setup notes: No official docker-compose. Community Docker images are inconsistently maintained. Requires building from source Dockerfiles. C2 listeners need direct port exposure which conflicts with Traefik-only routing. Qt client is a desktop app — no web UI to proxy. Teamserver is the only containerisable component._
  _Value notes: Blue 2/10 — understand attacker TTPs. Green 4/10 — test endpoint detections. Red 9/10 — top-tier C2 with advanced evasion. Pure offensive tool with limited defensive value._

- **Covenant** — Setup: 6/10 | Value: 3/10 | Priority Score: ★
  Collaborative .NET C2 framework with a web-based multi-user interface for managing command and control operations. Features dynamic compilation via Roslyn, encrypted communication, and cross-platform support (Linux, macOS, Windows).
  GitHub: https://github.com/cobbr/Covenant
  Docs: https://github.com/cobbr/Covenant/wiki/Installation-And-Startup
  Docker: `docker build -t covenant .` from repo; community image `warhorse/covenant` on Docker Hub
  _Setup notes: Dockerfile in repo but needs manual build — no official pre-built image. Community images may be outdated (project is less actively maintained). Web UI can proxy through Traefik. Listener ports need direct exposure. .NET runtime in container is heavy. Single container but build process can be flaky._
  _Value notes: Blue 2/10. Green 4/10 — .NET-focused C2 testing. Red 8/10 — .NET post-exploitation. Project is less actively maintained — Mythic and Sliver have surpassed it. Low priority unless specifically testing .NET-based attack detections._

- **Redcloud** — Setup: 5/10 | Value: 3/10 | Priority Score: ★
  Docker-based toolbox for rapidly deploying fully-featured red team infrastructure with minimal setup. Provides a web interface for managing offensive security tools (Metasploit, Empire, GoPhish), handling networking, SSL certificates, and container orchestration automatically. Supports local, SSH remote, and cloud (AWS/GCP) deployment.
  GitHub: https://github.com/khast3x/Redcloud
  Docker: Deployed via Redcloud orchestration; uses Portainer for management and Traefik for routing
  _Setup notes: Already Docker-native with its own Traefik — but that conflicts with the existing testing stack Traefik. Would need to either disable its built-in Traefik or run on separate ports. Its own orchestration tool manages everything, which may conflict with the manual compose approach. Good concept but needs adaptation._
  _Value notes: Blue 1/10. Green 4/10 — rapid red team infra for exercises. Red 8/10 — quick offensive tooling deployment. Primarily a red team convenience tool — you already have Docker infrastructure. Overlaps with what the testing stack itself does._
