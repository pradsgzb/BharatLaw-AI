# BharatLaw AI — Software Requirements Package v1.1

Document ID: BL-SRS-001  
Document date: 19 September 2026  
Status: Review draft; approvals remain pending.

## Open these files first

- `BharatLaw_AI_Software_Requirements_v1.1.pdf`: 62-page fixed-layout reading copy with linked contents and diagram guide.
- `BharatLaw_AI_Software_Requirements_v1.1.docx`: editable Word document for review, comments and change tracking.
- `BharatLaw_AI_Software_Requirements_v1.1.md`: text-based specification suitable for repository review and use alongside coding tools.
- `requirements_register.json`: 91 functional and 20 nonfunctional requirements with IDs, behavior, acceptance evidence, phase, ticket references and proposed status; also includes workflow identifiers and 30 acceptance scenarios.
- `diagrams/`: 15 diagrams, each supplied as editable Graphviz DOT and vector SVG. The document caption/figure number identifies its purpose; file numbering reflects asset creation order, not always the figure order in the document.
- `baseline/BharatLaw_AI_Codex_Handoff.zip`: unchanged original 34-file handoff, including reference SQL, OpenAPI/JSON contracts, search mappings, tickets and reference components.
- `DOCUMENT_QA.md`: checks performed on these documents and their limits.
- `SHA256SUMS.txt`: file integrity manifest for the package contents other than the manifest itself.

## Suggested reading paths

Product and nontechnical readers: Sections 2–5, then the glossary in Appendix D. These explain what the product does, who uses it, screens, workflows and exceptions.

Developers and Codex: Sections 6–15 and Appendices A–C, together with the original handoff. Use the requirement IDs in implementation tasks and test reports.

Legal, privacy and operations reviewers: Sections 5, 7–9, 11–16, and the explicit source/provider/retention decisions. All sign-off fields remain pending.

## Editing and handoff

Use Word for comments and proposed changes. The contents and diagram guide link to document bookmarks; displayed page references apply to this edition and need rechecking after substantial edits. Re-export and inspect the PDF after changes.

Edit a diagram in its `.dot` file. With Graphviz installed, render a new SVG, for example:

```bash
dot -Tsvg diagrams/01_context.dot -o diagrams/01_context.svg
```

The DOCX embeds rendered diagrams; replacing a DOT/SVG alone does not automatically update the Word file. Replace the corresponding figure and recheck its caption, page reference and readability.

Place the SRS and requirements register beside the extracted original handoff before implementation. Start with approved document import, canonical text and the exact-source viewer, not an unrestricted chatbot. The SRS follows the detailed Phase 0–6 ticket plan and explicitly identifies phase/run-state discrepancies for reviewed reconciliation.

Requirement status stays `proposed` until an authorized review and actual implementation/test evidence establish a different state. Synthetic examples are test material, not Indian law, and may not enter a production legal corpus.

## Evidence boundaries

This is a documentation and requirements deliverable, not a deployed product or a certification of legal correctness, privacy compliance, security, accessibility or performance. It does not newly verify current laws, source licences, provider terms, cloud availability or prices. The original handoff's reference-test report is not evidence that the full application is operating or validated. Live acquisition, paid calls, private data processing and deployment require their own approvals.
