# Shortbread does not export private product data

Shortbread itself never sends site content, feedback, invitation data, or viewer PII to AI, analytics, or optional third-party processors. Data is processed only by operator-configured Northflank, PlanetScale, and R2. Producers/agents outside Shortbread are operator-controlled. This makes the promise server-private rather than zero-knowledge: credentials and private data must also stay out of logs, issues, PRs, screenshots, fixtures, and handoffs, while saved Offline Copies are honestly documented as surviving revocation.
