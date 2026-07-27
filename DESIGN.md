<!-- SEED: re-run /impeccable document once there's code to capture the actual tokens and components. -->
---
name: Local Todo
description: A focused local-first task manager built on transparent Markdown files.
---

# Design System: Local Todo

## 1. Overview

**Creative North Star: "The Quiet Workbench"**

The interface is a precise working surface where tasks, dates, and file-backed structure remain close at hand without competing for attention. Things leads the hierarchy and interaction craft, while file-native details appear only when they help users understand or control their data.

The system is monochrome and adaptive rather than sterile. Contrast, weight, spacing, and restrained tonal layers establish hierarchy in both light and dark environments. Motion responds quickly to input and explains state changes; it never becomes choreography.

The product must not feel like a Jira issue editor. Task entry and review are workflows, not administrative forms.

**Key Characteristics:**
- Monochrome adaptive surfaces with semantic color reserved for meaning.
- Calm hierarchy with dense detail available on demand.
- Familiar controls refined through spacing, typography, and feedback.
- File-native cues that clarify behavior rather than decorate it.
- Responsive across desktop and mobile without diluting power-user workflows.

## 2. Colors

The palette is an adaptive range of subtly tinted near-neutrals; exact values will be resolved during implementation.

### Primary
- **Working Ink** (`[to be resolved during implementation]`): Primary text, selected states, and high-emphasis actions through contrast rather than hue.

### Neutral
- **Paper Surface** (`[to be resolved during implementation]`): Light-theme working surface, tinted rather than pure white.
- **Night Surface** (`[to be resolved during implementation]`): Dark-theme working surface, tinted rather than pure black.
- **Quiet Rule** (`[to be resolved during implementation]`): Dividers, inactive controls, and structural boundaries.

### Named Rules

**The Monochrome Discipline Rule.** Structure the product with tone, spacing, and weight. Introduce semantic hues only when they communicate priority, status, warning, success, or error.

**The Adaptive Surface Rule.** Dark mode is not an inversion. Each theme has its own surface hierarchy and contrast tuning.

## 3. Typography

**Display Font:** `[technical humanist sans to be chosen at implementation]`
**Body Font:** `[same family to be chosen at implementation]`

**Character:** One technical humanist sans carries the entire interface. It should be precise at compact sizes, open enough for long task titles, and neutral enough to let content lead.

### Hierarchy
- **Display** (`[to be resolved]`): Reserved for empty states and rare onboarding moments, never routine task screens.
- **Headline** (`[to be resolved]`): View titles and major navigation landmarks.
- **Title** (`[to be resolved]`): Task titles, project names, and section headings.
- **Body** (`[to be resolved]`): Notes and supporting content, capped at 65-75 characters where prose is continuous.
- **Label** (`[to be resolved]`): Metadata, controls, dates, priorities, and compact navigation.

### Named Rules

**The One Family Rule.** Hierarchy comes from size, weight, spacing, and numeric features, never from decorative font pairing.

## 4. Elevation

The system is flat by default. Tonal surface changes and one-pixel boundaries establish structure; elevation appears only for transient layers such as menus, command results, and dragged items. Exact shadow values will be resolved during implementation.

### Named Rules

**The Working Plane Rule.** Persistent content shares one visual plane. Never stack decorative cards or use shadow to compensate for weak hierarchy.

## 5. Components

Component tokens will be documented after the first implementation establishes real controls. Buttons, fields, task rows, navigation, metadata chips, menus, and the command palette must use one consistent state vocabulary across desktop and mobile.

Motion is responsive and functional: immediate press feedback, 150-250 ms state transitions, exponential ease-out for entrances, faster exits, and reduced-motion alternatives without spatial movement.

## 6. Do's and Don'ts

### Do:
- **Do** make capture the visually dominant action without turning every screen into a form.
- **Do** preserve strong text and component contrast in both adaptive themes.
- **Do** reveal dates, tags, priorities, and file details progressively.
- **Do** use familiar task-manager and platform affordances with precise spacing and focus behavior.
- **Do** communicate every state with text, shape, or iconography in addition to any semantic color.

### Don't:
- **Don't** reproduce the metadata density, process rigidity, or form-like task editing of a Jira issue editor.
- **Don't** introduce hidden storage behavior, opaque database semantics, or surprising file mutations.
- **Don't** enforce GTD through blocking steps or a rigid navigation sequence.
- **Don't** expose every control and piece of metadata at once.
- **Don't** use decorative motion, nested cards, glass effects, gradient text, or colored side-stripe borders.
- **Don't** use pure black, pure white, or chroma-free gray as final production colors.
