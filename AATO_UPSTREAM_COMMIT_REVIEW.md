# Upstream commits since the fork point — what's worth pulling

## Fork point

`make_taggable`'s history starts at a squashed "Initial commit" (7698fe0, 2020-11-16) with no
shared ancestry, so the base had to be recovered by matching blobs. The fork's initial tree is
**upstream v6.5.0** (`6b38c652`, 2019-10-29) — 62 of 75 Ruby/Markdown files match that tree
exactly, and the bundled `CHANGELOG.md` stops at the v6.5.0 release notes.

Since then upstream has 93 commits (v7.0.0 → v13.0.0), of which **39 touch `lib/` or `db/`**.
Everything below is that 39, reviewed one by one.

## The important negative result

**Upstream has not fixed any of the 29 confirmed bugs from the issue triage.** I checked HEAD
(`4d58c53`) directly:

- `ExcludeTagsQuery#tags_not_in_list` still hardcodes `taggable_arel_table[:id]`
- `AnyTagsQuery#build` still calls `select(all_fields)`
- `AllTagsQuery#order_conditions` still passes a raw string to `.order` without `Arel.sql`

So there is no shortcut: that backlog is ours to fix either way. What upstream *does* have that we
don't is a handful of small correctness fixes and three features.

---

## Worth pulling — correctness

| Upstream | What it fixes | Status here |
|---|---|---|
| **12f08be** (#1081, v10) | `find_or_create_all_with_like_by_name` issues a raw `ActiveRecord::Base.connection.execute "ROLLBACK"` when it hits `RecordNotUnique`. That breaks any enclosing transaction and ignores multiple-database setups. Upstream replaced it with `transaction(requires_new: true) { create(...) }`. | **We still have the raw ROLLBACK.** Highest-value pull on this list — it corrupts caller transactions, and our own spec suite runs inside a transaction. |
| **426d960 + a0cadfb** | `remove_unused_tags` handling when the counter cache is off, and avoiding a needless `tag.reload`. | **Ours is worse than upstream's pre-fix state.** `MakeTaggable.remove_unused_tags` is gated on `&& MakeTaggable.tags_counter`, so with `tags_counter = false` the setting silently does nothing. Verified: orphan tag survives. This is upstream issue #946 arriving by a different route. |
| **2a8acc1** (#1065) | `using_postgresql?` matches only `"PostgreSQL"`, so the PostGIS adapter falls through to the MySQL/generic path — `LIKE` instead of `ILIKE`, and the wrong `GROUP BY` strategy. | Absent. One-line fix: `%w[PostgreSQL PostGIS].include?(adapter_name)`. |
| **38fb4d2 / b915ca8** | `Utils.connection` uses the model-level `.connection`, soft-deprecated in Rails 7.2 in favour of `lease_connection`. | Absent. Worth taking since our floor is already AR 7.2 — go straight to `lease_connection`, no fallback branch needed. Note: I did **not** observe an actual deprecation warning on AR 8.1.3, so this is hygiene, not breakage. |
| **1df5ac3** | Upstream dropped four single-column indexes on `taggings` as redundant against the composite ones. | **Applies, and ours is worse.** Our migrations produce **12 indexes** on `taggings`. At least five are dead weight: `tag_id` (prefix of `taggings_idx`), `taggable_id` (prefix of `taggings_taggable_context_idx`), `taggable_type`, `tagger_id` (prefix of the tagger pair), and we create the tagger pair **in both column orders** (`index_taggings_on_tagger_id_and_tagger_type` *and* `index_taggings_on_tagger_type_and_tagger_id`, the latter from `t.references`). Every tagging insert pays for all of them. |

## Worth pulling — features

| Upstream | Feature | Note |
|---|---|---|
| **2014fcc** (#1082, v10) | `wild: :prefix` / `wild: :suffix` in addition to `wild: true`. | Small and self-contained, and it partly answers issue #1028: a suffix match (`foo%`) can use a plain btree index, where `%foo%` never can. |
| **52d7dae** (#1053, v9) | `all_tag_counts(id: [...])` accepts an array of taggable ids, not just one. | Lets a caller compute tag counts for a page of records in one query instead of N. Cheap to take. |
| **b4eed9b + 8ba7fee** (v9/v10) | A `base_class` config so `Tag` and `Tagging` inherit from the host's `ApplicationRecord` instead of `::ActiveRecord::Base` — needed for horizontally sharded / multi-database apps. 8ba7fee then changed it to a **String** because Zeitwerk won't let you reference a model constant at initializer time. | If we take this, take both commits: the String form is the correct one. Also relevant to issue #1103 (ownership + tenancy). |
| **7e696e3 + 4a7948e + e2d211b + 5d86cce** (v8) | A `tenant` column on `taggings`, `acts_as_taggable_tenant`, `Tag.for_tenant`, `Tagging.by_tenant`. | The largest item here — a migration plus API surface. Directly addresses issue #1103. I'd treat this as a "do we want it?" product decision rather than a pull; it overlaps with what `acts_as_tenant` already does in the host app. |

## Not worth pulling

| Upstream | Why not |
|---|---|
| **47da503** (case-sensitivity third arg to `matches`) | **Already present.** Our `query_base.rb` passes `MakeTaggable.strict_case_match`. |
| **b54771d** (`force_encoding('BINARY')` removal) | **Already present** — we fixed this independently in 1.0.0 and the CHANGELOG records it. |
| **f18679a** (drop `mb_chars` / `unicode_downcase`) | **Already present** — our `Tag` uses `name.to_s.downcase`. |
| **31f29c9** (caching always on) | This deletes the lazy `columns` interception that upstream themselves added in PR #911 to avoid clobbering a host's own `columns` override. Our `Cache::Columns` is the better design and we have a spec for it (`ColumnsOverrideModel`). Taking this would be a regression. |
| **93fd6d2, a54cc54, bdb86da** (v11 `ActiveSupport::Concern` / Zeitwerk refactors) | Pure restructuring of code we have already restructured differently in 1.0.0. No behaviour change. |
| **380c0bc** (combine migrations into one) | Upstream folded migrations 1–7 into a single idempotent `SetupActsAsTaggableOn`. Tempting, but our six-migration chain is already published and 1.1.0 just added migration 6 — collapsing them now would break `install:migrations` for existing installs for no functional gain. Take the *index trimming* from 1df5ac3 without the consolidation. |
| **89a4d7f, 37bfebc, 4c49575, cfd6e06, 866c38f, 46c4e2d, f7bfad9, 69e6bff, b1d7651, 6fa6b55, 8548529, e0f859e, 6fbd9d1, b7122b9, 25266d6, 954e7ce** | Release commits, CI/docker chores, formatting, Ruby 2.7 / Rails 6.1 / Rails 8 compatibility we already exceed, and migration-syntax cleanups against migration files we don't share. |

---

## Recommendation

Four small commits are worth taking more or less as-is, and they're cheap:

1. **12f08be** — the raw `ROLLBACK` (correctness, affects callers' transactions)
2. **remove_unused_tags with `tags_counter = false`** (our own regression, upstream-adjacent)
3. **2a8acc1** — PostGIS adapter detection
4. **1df5ac3-style index trim** — but sized to our 12-index reality, as a *new* migration 7 that drops the redundant ones rather than by editing migration 5

Then **2014fcc** (`wild: :prefix`/`:suffix`) and **52d7dae** (array `:id`) as easy feature wins.

`base_class` and the tenant feature are both real decisions rather than pulls — worth discussing
before either lands.

None of this changes the issue triage: the 29 confirmed bugs have no upstream fix to inherit.
