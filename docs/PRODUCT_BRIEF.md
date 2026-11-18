# LearningCape Product Brief

Path: `docs/PRODUCT_BRIEF.md` · Status: **Draft** · Date: 2026-11-18 · Source: owner decisions in the planning session of that date.

## 1. What it is
A standalone web app that guides a person through curated AI learning for their role and tracks what they have completed. It has no dependency on, or integration with, any other project.

## 2. Decisions (confirmed by the owner)
| Topic | Decision |
|---|---|
| Scope | Standalone web app. |
| User | Individuals first. Features should resemble an organisational AI-literacy tool (structured paths, clear progress, a record of completion), but organisations are **not** tracked yet. |
| Organisations | Not built now. The database must be able to accommodate them later without a rewrite. |
| Competency | Not certified. The first competency indicator is progress of completed courses. Testing (quizzes) may be added later. |
| Content | Third-party, free sources only at first. Formats vary (course, video, article, repo, docs). LearningCape provides and curates the links and short descriptions. Own coursework and labs may come later. |
| First success measure | A first user can test the app and use every feature end to end. |
| Languages | English first, Czech second. |

## 3. Assumptions (not yet confirmed)
1. **AI assistant:** kept as built for now (recommends only curated links), and hidden when no LLM key is configured. Rebuild or removal is undecided.
2. **Accounts:** anonymous sessions stay the default; an optional email sign-in for cross-device use is added before wider release.
3. **Curriculum storage:** stays a reviewed JSON file in the repo until own coursework exists.
4. **Vendor neutrality:** content should cover several AI vendors, not mostly one.
5. **Hosting:** undecided (see `docs/PLAN.md`, open decisions).

## 4. Out of scope for the first release
Organisations, roles and admin reporting; quizzes and certificates; own courses and labs; payments; Czech translation (the app is made translation-ready only).

## 5. Gap Review
- [ ] Owner confirms or changes each assumption in section 3
- [ ] Controller identity and AI provider named (also open in `docs/SECURITY.md` section 7)
- [ ] Hosting and domain chosen
