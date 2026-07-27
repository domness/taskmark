# Product

## Register

product

## Users

Individual power users who want a fast daily task manager without surrendering ownership of their data. They are comfortable with local files and may edit Markdown directly, but they expect the app to make routine capture, planning, and completion faster than manual file management.

## Product Purpose

Provide a dependable local-first system for capturing and completing work through a focused app interface and transparent Markdown files. The product should combine the calm craft of Things, the capture speed of Todoist, and the file ownership of Obsidian. Success means it can become a user's daily driver while remaining understandable and recoverable outside the app.

## Brand Personality

Focused, fast, technical. The product should feel precise and capable without becoming cold, noisy, or demanding. Its voice is concise, direct, and respectful of the user's attention.

## Anti-references

- Hidden storage behavior, opaque database semantics, or surprising file mutations.
- Rigid GTD enforcement that prevents users from adapting the system to their own workflow.
- Productivity interfaces that expose every control and piece of metadata at once.
- Decorative interaction that slows capture or interrupts task flow.

## Design Principles

### Files are the contract

Markdown remains legible, stable, and useful without the app. App actions must map to predictable file changes that users can inspect and reproduce.

### Capture first, organize progressively

Adding a task should be nearly frictionless. Projects, areas, tags, dates, deadlines, and priorities should be available when useful, not required before capture.

### GTD is a framework, not a gate

Provide strong defaults for inbox processing and next actions while allowing users to shape folders, metadata, and views around their own practice.

### Calm surface, powerful depth

Keep primary workflows focused and visually quiet. Reveal metadata, file operations, and advanced controls deliberately rather than presenting a dense dashboard by default.

### Local-first means trustworthy

The product must behave predictably offline, preserve user-authored content, surface conflicts clearly, and never imply that synchronization is safer or more complete than it is.

## Accessibility & Inclusion

Target WCAG 2.2 AA. All core workflows must support keyboard operation, visible focus, reduced motion, scalable text, and state cues that do not rely on color alone. Dense power-user interactions must retain accessible labels and understandable alternatives.
