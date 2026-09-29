# How we chose the models in this kit

We tested AI browser agents on real websites on September 27 and 28, 2026, before choosing what this kit uses. Every agent used the same signed-in Chrome Beta browser, the same instructions and the same pass/fail rules. We ran the tests one at a time and timed them from start to finish.

## The short answer

| What you're doing | What the kit uses | Result in testing |
|---|---|---|
| Finding the right page or product on a public site | **jev-drive**: Jev clicks, GPT-6 Sol takes any step Jev is unsure of | 24 of 24 tasks right, about 5–30 seconds and 3 cents each |
| Anything behind your login (orders, portals, CRMs) | **Codex with GPT-6 Sol** | 7 of 7 both days, picked the exact product every time |
| A quick check while you watch, from Claude Code | **Claude Sonnet 5.5** | 7 of 7, exact product every time, the fastest agent |

## The tests

Seven tasks for each agent:
- **Wikipedia (3 times):** find and open the article on Gödel's incompleteness theorems.
- **Amazon (3 times):** search for *teal* acoustic panels and open a teal one. This is the detail test: the top results are black and wood-grain panels, and a sponsored banner sits above them. It only counts if the product's title names the colour.
- **Costco (once):** open the order history on a signed-in account without typing anything.

## Agent results

| Agent | Tasks done | Right colour | Time for all 7 | Cost for all 7* |
|---|---|---|---|---|
| Claude Sonnet 5.5 | 7/7 | 3/3 | 224 s | $2.60 |
| Codex, GPT-6 Sol | 7/7 | 3/3 | 384–407 s | $0.99–1.21 |
| Codex, GPT-5.6 Sol | 7/7 | 3/3 | 372 s | $2.39 |
| Codex, GPT-5.6 Terra | 7/7 | 2/3 | 348 s | $1.40 |
| Codex, GPT-6 Astra | 7/7 | 2–3/3 | 418–465 s | $3.74–4.31 |
| Codex, GPT-6 Luna | 7/7 | 1/3 | 354 s | $0.05 |
| Claude Sonnet 5 | 7/7 | 1/3 | 221 s | $2.61 |

\*Costs are what the same usage would cost at each company's API list price. If you run Claude Code or Codex on a subscription, you pay nothing extra per task.

**What this means:** GPT-6 Sol and Sonnet 5.5 are the two agents that got every detail right. Sol costs about half as much; Sonnet 5.5 is about twice as fast. The cheapest agent (Luna) settled for the wrong colour 2 out of 3 times, so it saves money only if you don't mind checking its work.

## Jev: very fast, but it needs a partner

Jev (from TypeSafe) picks each click in about a tenth of a second. That made it 5–13× faster than any agent and nearly free, but it has no judgement. On Amazon it clicked the sponsored banner or the first panel every time and never checked the colour.

For each step, Jev also reports how confident it is. We logged 99 of Jev's steps across 8 tasks, checked every one, and found 7 mistakes. **Every mistake happened when Jev's confidence was below 93%.** So jev-drive lets Jev click when it is at least 93% confident and hands every other step to GPT-6 Sol:

| Setup (8 tasks, 3 times each) | Tasks right | Cost per task |
|---|---|---|
| Jev alone | 19 of 24 | under 1 cent |
| **Jev + GPT-6 Sol (what the kit uses)** | **24 of 24** | **about 3 cents** |
| Jev + Claude Sonnet 5.5 | 21 of 24 (wrong colour all 3 times) | about 6 cents |

Two setups that didn't work:
- **Letting Jev finish and checking at the end.** The checking agent accepted Jev's wrong-colour panel 3 out of 3 times. The check has to happen step by step.
- **Using Jev on signed-in pages.** Jev sends each page's visible text to TypeSafe's servers. jev-drive refuses any site that isn't on its public list, and stops at every sign-in page.

## Limits

- These were small tests: 3 repeats per task and 8 kinds of task. Treat them as a strong direction, not a guarantee.
- We chose the 93% cutoff and tested it on the same 8 tasks. It will keep being checked on new tasks.
- Websites change. A site's layout or search results can differ from one day to the next.
- Model prices and versions change. These numbers are from September 2026.
