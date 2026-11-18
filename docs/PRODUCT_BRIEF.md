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
| Deployment | The app runs locally on the user's computer; it is **not** hosted. Only the data is hosted (Supabase). It ships as one wrapped desktop app with nothing separate to install or start. |
| Search | The curriculum and the app's own content must be searchable. |
| Sign-in | Email and password only at first. No MFA during the testing period, because it gets in the way of feature testing. |

## 3. Assumptions (not yet confirmed)
1. **AI assistant (owner intent, 2026-11-18):** designed for Sign in with ChatGPT, so each user's own ChatGPT plan pays for their questions; initial testing uses the owner's login. Constraint found in OpenAI's docs (developers.openai.com/siwc, checked 2026-11-18): plan usage is self-serve only for open-source and locally hosted apps; a remotely hosted app must be accepted through OpenAI's interest form (limited trial). Because the app runs locally (see Deployment), the self-serve flow applies: ChatGPT redirects to `http://127.0.0.1`, so the wrapped app itself listens for that callback and sends the requests (a plain web page cannot do this). No OpenAI approval is needed while the app stays local.
2. **Accounts:** email and password sign-in replaces anonymous sessions as the way into the cloud features; the app still works on one device without signing in. Email confirmation is switched off during testing. Both points need owner confirmation.
3. **Curriculum storage:** stays a reviewed JSON file in the repo until own coursework exists.
4. **Vendor neutrality:** content should cover several AI vendors, not mostly one.
6. **Search scope:** one search box covering every track's modules and resources (title, description, provider, format) plus the user's vault (title, notes). It runs in the browser with no server call, so it works offline and sends nothing to a third party.
5. **Packaging:** the desktop wrapper framework is undecided (see `docs/PLAN.md`, open decision 2). A desktop app does not run on an iPad or phone.

## 4. Out of scope for the first release
Organisations, roles and admin reporting; quizzes and certificates; own courses and labs; payments; Czech translation (the app is made translation-ready only).

## 5. Gap Review
- [ ] Owner confirms or changes each assumption in section 3
- [ ] Controller identity and AI provider named (also open in `docs/SECURITY.md` section 7)
- [ ] Packaging of the local app chosen
