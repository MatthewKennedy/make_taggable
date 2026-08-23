# acts-as-taggable-on open issues — applicability to MakeTaggable

All 66 open issues on `mbleigh/acts-as-taggable-on` (as of 2026-08-23) checked against
`make_taggable` at 1.1.1. Everything marked **confirmed** was reproduced by running code
against the gem's own SQLite harness (Ruby 4.0.1 / Active Record 8.1.3); everything marked
**static** was read out of the source. Adapter-specific reports that need MySQL/PostgreSQL
are listed separately as unverified.

Verdict counts: 29 apply, 5 apply as feature gaps, 13 do not apply, 8 unverified,
11 documentation issues already covered.

---

## Applies — confirmed by reproduction

### Query builder

| Upstream | Symptom in MakeTaggable | Evidence |
|---|---|---|
| #402, #993 | `tagged_with` returns a record once per matching tagging. A record tagged `"interesting"` in two contexts comes back twice. No `DISTINCT`, no context filter. | `OtherTaggableModel.tagged_with("interesting")` → 2 rows for 1 record |
| #701 | `:exclude` ignores `:on`. `ExcludeTagsQuery#tags_not_in_list` builds no context predicate at all. | generated SQL contains no `context` clause |
| #630 | `tagged_with([], exclude: true)` returns nothing. `core.rb` returns `none` on an empty list before the strategy is chosen, so "exclude nothing" excludes everything. | 0 rows, should be all |
| #1094 | `tagged_with(tags, order_by_matching_tag_count: true)` raises `ActiveRecord::UnknownAttributeReference`. `AllTagsQuery#order_conditions` passes a raw subquery string to `.order`. | raises; the `any: true` path is fine because it wraps in `Arel.sql` |
| #692, #1109, #530 | `.count` / `.size` on an `any: true` relation emits `COUNT("table".*)`, which is invalid SQL on SQLite, MySQL and PostgreSQL. Chaining two `tagged_with` calls compounds it. | `SQLite3::SQLException: near "*"` |
| #936 | `AnyTagsQuery#build` calls `select(all_fields)`, so a caller's own `select` is appended rather than honoured. Also what breaks #395 (`merge` overwriting the SELECT). | `SELECT "taggable_models".*, "taggable_models"."id"` |
| #915 + our own | `ExcludeTagsQuery#tags_not_in_list` hardcodes `taggable_arel_table[:id]` instead of the model's primary key. Any model with a non-`id` primary key raises on `exclude: true`. This is strictly worse than the upstream report. | `NonStandardIdTaggableModel.tagged_with(["k"], exclude: true)` → `StatementInvalid` |
| #277, #387 | No way to order by `taggings.created_at`. `tagged_with` hides the taggings behind SHA aliases; `all_tags(order: "taggings.created_at desc")` builds a subquery that doesn't project the column. | `no such column: taggings.created_at` |
| #293 | `tagged_with` still emits one `INNER JOIN` per tag in the default (all-tags) mode. | 12 tags → 12 joins |
| #1028, #657 | `QueryBase#tag_match_type` wraps the column in `LOWER()` unconditionally. On PostgreSQL the operator is already `ILIKE`, so the `LOWER()` is redundant *and* defeats `index_tags_on_name`. Same cause as the #657 cache-miss report. | static + confirmed in generated SQL |
| #328 | SQLite's `LOWER()` is ASCII-only, so `Tag.named_any` misses case variants of non-ASCII names. | `Tag.named_any(["ünicode"])` → 0 for a tag named `"Ünicode"` |

### Attribute / dirty tracking

| Upstream | Symptom | Evidence |
|---|---|---|
| #1024, #1064, #1029 | `tag_list` is declared as an `attribute`, so it appears in `as_json` (triggering a tag query per record) but reads back `nil` from `attributes`. | 19 queries to serialize 3 records; `attributes["tag_list"] == nil` |
| #1155 | `tag_ids = []` after `as_json` silently does nothing — the tags stay attached. | tags survive the assignment |
| #373 | `tag_list.add(...)` / `.remove(...)` mutate the array in place without `attribute_will_change!`, so `tag_list_changed?` stays false. Only whole-list assignment is tracked. | `false` after `.add("sfw")` |
| #1047 | `TagList#remove` compares raw objects, so `remove(:foo)` is a no-op while `remove("foo")` works. | list unchanged |
| #1139 | `TagList` carries `@parser`, which holds a *Class*. `Psych.safe_dump` refuses it, so anything serialising a taggable to YAML (audited, ActiveJob args) blows up. | `Psych::DisallowedClass: Tried to dump unspecified class: Class` |

### Saving

| Upstream | Symptom | Evidence |
|---|---|---|
| #1176 | `strict_loading` is violated on save. `save_tags` → `tagging_contexts` → `custom_contexts` lazily loads `taggings`. | `StrictLoadingViolationError` on saving a persisted record |
| #1128 | The same path means every save — even a no-op — issues tagging queries. | 3 queries on a save with no changes |
| #665 | A tag over 255 characters fails `Tag`'s length validation, `create` returns it unsaved, and the taggable then fails with a misleading `Validation failed: Tag can't be blank`. | raises `RecordInvalid` |
| #508 | `Tag.find_or_create_all_with_like_by_name` uses non-bang `create`, so validation errors added by a `Tag` subclass are swallowed and surface later as the wrong error. | static |
| #947 | `save_tags` and `save_owned_tags` create taggings in list order, so two concurrent saves touching the same tags can deadlock on the `taggings_count` counter cache. Sorting `new_tags` by id would fix it. | static |
| #290 | `preserve_tag_order` is one `class_attribute` for the whole model, so `make_taggable` and `make_ordered_taggable` in the same class clobber each other — the last call wins for every context. | `make_taggable :skills` + `make_ordered_taggable :books` → `preserve_tag_order?` is `true` for `:skills` |
| #1044 | A context whose name starts with a digit raises a **`SyntaxError`** while the class body loads (we generate `def 1category_taggings`). Upstream only got an invalid-ivar error, so ours fails harder. | `SyntaxError` from `has_many` |

### Ownership and caching

| Upstream | Symptom | Evidence |
|---|---|---|
| #233 | `Tagger#tag` does not refresh `cached_<context>_list`. `save_cached_tag_list` only mirrors unowned lists, so a cached column silently drifts from `all_tags_list`. | `cached_tag_list` stayed `nil` while `all_tags_list == ["owned"]` |
| #571 | `Tagger#tag` always parses `:with` through the default parser. There is no `parse: false`, so a tag legitimately containing a comma is split into two. | `with: ["a, b"]` → `["a", "b"]` |

### Configuration

| Upstream | Symptom | Evidence |
|---|---|---|
| #781, #945 | `force_binary_collation=` still issues an `ALTER TABLE` every time it's called. Set in an initializer, that runs on every boot — including every Sidekiq/cron process — and takes a metadata lock on the tags table. | `apply_binary_collation` still calls `ActiveRecord::Migration.execute` |
| #769 | `force_parameterize` maps tags through `String#parameterize`, which reduces a fully non-ASCII tag to the empty string and `clean!` then drops it. | `["日本語", "ok tag"]` → `["ok-tag"]` |

## Applies — feature gaps rather than bugs

| Upstream | Gap |
|---|---|
| #91 | No eager-loading path for tag lists. `includes(:tags)` doesn't stop `tag_list` re-querying (13 queries for 5 records). |
| #804 | `tagged_with(tags, on: [:skills, :interests])` raises `TypeError: can't quote Array`. Only one context per call. |
| #783 | The `Tag` class is hardcoded. `find_or_create_tags_from_list_with_context` lets you create subclass rows, but the associations still return `MakeTaggable::Tag`. |
| #909 | `all_tags` / `all_tag_counts` accept no scope on the taggable's own attributes (`assert_valid_keys` rejects `:scope`). |
| #698 | The generated migration has no `type:` on the polymorphic references, so a UUID-keyed taggable needs the migration edited by hand. Not documented. |

## Does not apply

| Upstream | Why |
|---|---|
| #908, #914 | `Model.create!(tags: [tag])` works — the tagging saves with the default context. |
| #1151 | Repeated single-context `make_taggable` calls define `<context>_from` correctly; `Ownership.included` re-runs on every call. |
| #576 | Adding a tag in a second context does not delete the first context's taggings. |
| #867 | Chaining `tagged_with` with the same tag produces one join — Active Record dedupes the identical alias. |
| #1033 | `tagged_with(..., exclude: true)` returns the same result on a relation as on the class. |
| #946 | `remove_unused_tags` behaves as documented; re-tagging after a removal works. |
| #1023 | Ordered taggable + owner works. Our `order` argument is a bare `taggings.id`, which Active Record accepts. |
| #1099 | `upsert_all` on a taggable model works. |
| #395 | The `merge` symptom is #936's `select(all_fields)`, already listed. Not separately actionable. |
| #300 (part) | `find_related_*.blank?` works; only `.count` is broken (listed as #300/#907). |
| #455, #603 | Caching is documented — `docs/caching.md`. |
| #848 | The array form of the strong parameter is documented in `docs/getting-started.md`. |
| #981 | Docs already use `rails make_taggable_engine:install:migrations`, not `rake`. |
| #885 | `docs/ownership.md` builds owned lists from `locations_from(user)`, not `all_tags_list`, so the cascade the issue describes can't happen. |
| #754 | `tagged_with` parsing its argument is documented on the method. |

## Unverified — needs a PostgreSQL or MySQL run

| Upstream | What to check |
|---|---|
| #852 | `tag_counts_on` on a relation built with `includes(...).where(other_table: ...)` → "subquery has too many columns". Our `generate_tagging_scope_in_clause` does `except(:select).select(pkey)`, which may already fix it. |
| #1026 | `find_related_*` groups by every column on PostgreSQL; a `json` column has no equality operator and breaks `GROUP BY`. `Related#group_columns` still does this. |
| #1069 | Ambiguous column on `.count` with a joined scope. Did not reproduce on SQLite. |
| #1100 | "no implicit conversion of nil into String" on update — no reproduction in the issue. |
| #1103 | Ownership with `acts_as_tenant`: owned taggings created through `taggings.create!` and destroyed through a bare `Tagging.where(...)` may bypass the tenant scope. |
| #810 | Ordering against `acts_as_nested_set` — depends on callback order in the host app. |
| #657 | The PostgreSQL index-miss half of #1028; needs an `EXPLAIN` on a real table. |
| #915 | The integer-vs-varchar join half (separate from the primary-key bug above). |

---

## Suggested order of work

1. **#1044** — a `SyntaxError` at class-load time. Cheapest fix (validate the context name, or reject it with a clear error) and the worst failure mode.
2. **#915/exclude** — `ExcludeTagsQuery` hardcoding `:id`. One-line fix, silently wrong today.
3. **#701, #630** — `:exclude` ignoring context and the empty-list short circuit. Both are wrong *answers*, not errors.
4. **#402/#993** — duplicate rows from `tagged_with`. Needs a decision on `DISTINCT` vs. a subquery.
5. **#692/#1109/#530, #936, #1094** — the `AnyTagsQuery` select and the `AllTagsQuery` order. `.count` not working on a documented query option is a hard edge.
6. **#1139, #1047, #373** — small, self-contained `TagList` fixes.
7. **#1176, #1128** — stop `save_tags` loading `taggings` when nothing was assigned.
8. **#1024/#1064/#1029, #1155** — the `attribute :tag_list` design. The largest change; worth its own discussion.
