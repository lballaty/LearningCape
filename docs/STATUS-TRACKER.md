# LearningCape Status Tracker

Path: `docs/STATUS-TRACKER.md` · Status: **Draft** · Last updated: 2026-11-18 (end of the first planning session, cloud).
Update this file at the end of every session. Plan detail lives in `docs/PLAN.md`; this file says where things stand.

## Start here (next session, on the owner's Mac)
1. Confirm Xcode and Flutter are installed (`flutter doctor`).
2. Run the prototype in `prototypes/siwc_prototype/` on macOS, iPad and iPhone, following its README. The owner signs in with their ChatGPT account.
3. Record the results in the "Prototype results" table below.
4. Then start F1 (`docs/PLAN.md`), unless the owner directs otherwise.

## Milestones
| ID | Milestone | State | Notes |
|---|---|---|---|
| F0 | Supabase bring-up | Blocked on owner | Probed 2026-11-18: project reachable; `0001_init.sql` not applied; anonymous sign-ins off; no functions deployed |
| F1 | Flutter foundation (`app/`) | Not started | Can start now |
| F2 | Feature parity with the web app | Not started | Needs F1 |
| F3 | Accounts and sync | Not started | Needs F0 |
| F4 | Content expansion | Not started | Owner approves content |
| F5 | Search and tracker features | Not started | Needs F2 |
| F6 | Assistant on the user's ChatGPT plan | Prototype written | Logic passes 9 tests against a mock server. Not built for Apple targets; not run against OpenAI |
| F7 | Languages | Not started | English first, Czech later |
| F8 | First-user release | Not started | Needs controller name and contact |

## Prototype results (owner fills in, or the agent on the Mac)
| Device | Builds | Sign-in quick | Sign-in after 30s+ in browser | Models listed | Answer streamed | Still signed in after restart |
|---|---|---|---|---|---|---|
| macOS | | | | | | |
| iPad | | | | | | |
| iPhone | | | | | | |

## Waiting on the owner
1. Supabase dashboard: run `supabase/migrations/0001_init.sql`; enable anonymous sign-ins (testing starts with anonymous sessions).
2. Prototype run on the three devices.
3. Controller name and contact for the privacy notice (blocks F8 only).
4. Confirm the assumptions in `docs/PRODUCT_BRIEF.md` section 3.

## Decisions log (all 2026-11-18, by the owner)
| # | Decision |
|---|---|
| 1 | Standalone product; no link to other projects |
| 2 | Individuals first, with organisation-style features; database must allow organisations later |
| 3 | Completion progress is the first competency indicator; testing later |
| 4 | Content is curated free third-party links with short descriptions; own coursework and labs later |
| 5 | First success measure: a first user can test and use every feature |
| 6 | English first, then Czech |
| 7 | Sign-in will be email and password, no MFA in the testing period |
| 8 | Testing can start with anonymous sessions (these do exercise row-level security: each session is its own user) |
| 9 | Assistant uses Sign in with ChatGPT; owner's login for testing, each user's own later |
| 10 | Curriculum and app content must be searchable |
| 11 | App runs on the user's device; only the data is hosted |
| 12 | One app, no separate server |
| 13 | Flutter; first targets macOS, iPad, iPhone |

## Verified facts worth keeping
- Web app (reference only): script integrity hash matches, curriculum copies identical, built CSS current, local-mode browser smoke test passed. Its Supabase paths were never run.
- OpenAI docs (developers.openai.com/siwc, read 2026-11-18): the no-approval ChatGPT sign-in is for open-source and locally hosted apps and requires an HTTP callback on `127.0.0.1`; hosted apps need the interest form.
- Reference implementation that the owner has run successfully: `SearchingFool/Safari-ai-agent`, `app/browser-host/Sources/ChatGPTSIWC.swift` and `ChatGPTResponses.swift`.

## Session log
| Date | Where | Summary |
|---|---|---|
| 2026-11-18 | Cloud | Imported the web app from a zip; verified it; set Supabase URL and anon key; wrote brief and plan; chose Flutter; wrote and unit-tested the ChatGPT sign-in prototype |
