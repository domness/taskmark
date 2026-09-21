# Recurrence And Checklist Transitions

Read before completing a recurring task or changing its recurrence/checklist behavior. All calculations use calendar days in the vault timezone, not multiples of 86,400 seconds. Calendar display preferences do not redefine the recurrence calendar.

## Definitions

```yaml
recurrence:
  mode: fixed
  rule: FREQ=WEEKLY;BYDAY=MO,WE,FR
```

Fixed rules accept only this strict RFC 5545 subset:

- Required `FREQ=DAILY|WEEKLY|MONTHLY|YEARLY`.
- Optional `INTERVAL` integer 1–999, default 1.
- Optional `BYDAY`, only for WEEKLY, with unique comma-separated `MO,TU,WE,TH,FR,SA,SU` values.
- No other rule fields (for example COUNT, UNTIL, BYMONTHDAY) are supported.

```yaml
recurrence:
  mode: after-completion
  interval: P3D
```

After-completion accepts exactly `P<n>D`, `P<n>W`, `P<n>M`, or `P<n>Y`, with integer n from 1–999; not combined durations or time units.

Preserve unknown sibling keys in `recurrence`. A mode change removes only the other mode's known `rule`/`interval` key. Removing recurrence intentionally removes the whole mapping.

## Completion Algorithm

1. Reject canceled tasks until explicitly reopened. Use the latest valid rule, dates, notes, and reset preference, including any edits requested together with completion.
2. Record the UTC completion instant and its vault-local calendar day. The old planning anchor is `scheduled`, else `deadline`, else the completion day.
3. For **after-completion**, add the interval to the completion day. For **fixed**, advance the old planning anchor by one occurrence, then repeatedly advance until strictly after the completion day. Early completion still advances at least once. Do not re-anchor late fixed tasks on today.
4. With a scheduled date, replace it with the next date. With only a deadline, replace that deadline. With neither, create `scheduled`. When both exist, preserve the deadline's signed calendar-day offset from the old scheduled date, even when negative or spanning daylight-saving changes.
5. In the same document update, set `status: next`, clear `completed_at`, and set `updated_at` to the completion instant. Keep the exact path and `created_at`. Do not create a new occurrence file or history entity.
6. Leave notes unchanged unless `reset_checklist_on_repeat` is true, in which case reset only recognized checked markers as described below. Validate and publish once; a retry must not advance the already-advanced task again.

Calendar month/year additions clamp to the destination month's valid day. Repeated advancement uses the newly clamped date: January 31 → February 28 → March 28, not March 31. Weekly rules without BYDAY preserve the anchor weekday. With BYDAY, choose the next accepted weekday in an eligible recurrence week: the anchor week is eligible and later week-start differences must be multiples of INTERVAL. Match Taskmark's Gregorian calendar behavior, not a general RRULE library's broader defaults. If the available calendar library cannot establish the same weekly boundary/clamping behavior, leave completion unapplied and explain the ambiguity rather than approximate it.

Examples (dates in the vault timezone):

| Before | Completed on | After |
| --- | --- | --- |
| Scheduled Sep 14, deadline Sep 16, `FREQ=DAILY` | Sep 21 | Scheduled Sep 22, deadline Sep 24, Next |
| Scheduled Sep 14, deadline Sep 16, `P3D` after completion | Sep 21 | Scheduled Sep 24, deadline Sep 26, Next |
| Deadline Sep 25 only, `FREQ=DAILY` | Sep 21 | Deadline Sep 26 only, Next |
| No dates, `P1W` after completion | Sep 21 | Scheduled Sep 28, Next |

To finish permanently, explicitly remove recurrence and perform non-recurring completion (`done` with a completion timestamp). Cancel/reopen and reschedule operations do not calculate a repeat.

## Recognized Body Checklists

Interactive items have up to three leading spaces, then `-`, `*`, `+`, or a 1–9 digit ordered marker ending in `.` or `)`, whitespace, and `[ ]`, `[x]`, or `[X]`. The closing bracket is followed by whitespace or end-of-line.

Four-space indented code, blockquotes, escaped markers, HTML comments, and fenced code blocks are not interactive. Do not use a global checkbox regex that would change examples inside code or comments. Treat ambiguous/complex Markdown as notes rather than rewriting it.

Toggle/reset replaces only the single byte between brackets. Preserve all other bytes, including Unicode, line endings, indentation, and spacing. Repeat reset changes recognized `[x]`/`[X]` to `[ ]`; unchecked items stay unchanged. Ordinary non-recurring completion never resets checklists, even if the preference is true.
